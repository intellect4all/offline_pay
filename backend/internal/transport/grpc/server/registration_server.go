package server

import (
	"bytes"
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/service/registration/attestation"
	pb "github.com/intellect/offlinepay/internal/transport/grpc/gen/offlinepay/v1"
)

// attestationChallengeTTL caps how long a GetAttestationChallenge nonce
// remains valid. Short enough that replays are uninteresting; long
// enough to tolerate mobile attestation round-trips on a bad network.
const attestationChallengeTTL = 5 * time.Minute

// RecoveryGate validates an out-of-band recovery proof (OTP response, KYC
// re-verify voucher). A nil RecoveryGate is treated as "accept any non-empty
// proof" — safe for dev, NEVER safe for production. Wire a real impl before
// enabling recover flows outside the test environment.
type RecoveryGate interface {
	Verify(ctx context.Context, userID string, proof []byte) error
}

type devRecoveryGate struct{}

// Verify accepts any non-empty proof; intended for local dev + unit tests
// only. A warning is logged at process start if no production gate is wired.
func (devRecoveryGate) Verify(_ context.Context, _ string, proof []byte) error {
	if len(proof) == 0 {
		return status.Error(codes.InvalidArgument, "recovery_proof required")
	}
	return nil
}

// RegistrationServer implements pb.RegistrationServiceServer. Device
// hardware attestation is verified via the pluggable Attestation
// verifier (Play Integrity / DeviceCheck in production, DevVerifier in
// homelab / tests). A nil Attestation is treated as "pre-rollout" and
// accepts empty blobs — never wire that way in production.
type RegistrationServer struct {
	pb.UnimplementedRegistrationServiceServer

	Repo        *pgrepo.Repo
	Recovery    RecoveryGate
	Attestation attestation.Verifier
	Nonces      attestation.NonceStore
}

// NewRegistrationServer constructs a RegistrationServer with the dev
// recovery gate. Override .Recovery and .Attestation with production
// implementations. A MemoryNonceStore is wired by default so single-node
// homelab deployments get working challenge/response out of the box.
func NewRegistrationServer(repo *pgrepo.Repo) *RegistrationServer {
	return &RegistrationServer{
		Repo:     repo,
		Recovery: devRecoveryGate{},
		Nonces:   attestation.NewMemoryNonceStore(),
	}
}

// GetAttestationChallenge issues a fresh single-use nonce for the
// calling user; the client embeds it in its attestation blob.
func (s *RegistrationServer) GetAttestationChallenge(ctx context.Context, req *pb.GetAttestationChallengeRequest) (*pb.GetAttestationChallengeResponse, error) {
	if req.GetUserId() == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	if s.Nonces == nil {
		return nil, status.Error(codes.FailedPrecondition, "attestation nonces not configured")
	}
	nonce, err := s.Nonces.Issue(ctx, req.GetUserId(), attestationChallengeTTL)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "issue nonce: %v", err)
	}
	return &pb.GetAttestationChallengeResponse{
		Nonce:     nonce,
		ExpiresAt: timestamppb.New(time.Now().UTC().Add(attestationChallengeTTL)),
	}, nil
}

// verifyAttestation consumes the server-issued nonce (if a nonce store
// is configured) and runs the registered attestation verifier. When the
// server has neither wired, it accepts an empty blob — homelab /
// pre-rollout posture. Production deployments must wire Attestation.
func (s *RegistrationServer) verifyAttestation(ctx context.Context, userID, platform string, blob, nonce, devicePub []byte) (attestation.Attestation, error) {
	if s.Attestation == nil && s.Nonces == nil {
		// Legacy / pre-rollout: accept whatever the client sent.
		return attestation.Attestation{}, nil
	}
	if s.Nonces != nil {
		if err := s.Nonces.Consume(ctx, userID, nonce); err != nil {
			if errors.Is(err, attestation.ErrNonceMismatch) {
				return attestation.Attestation{}, status.Error(codes.FailedPrecondition, "attestation nonce invalid or already consumed")
			}
			return attestation.Attestation{}, status.Errorf(codes.Internal, "consume nonce: %v", err)
		}
	}
	if s.Attestation == nil {
		return attestation.Attestation{}, nil
	}
	platformKey := attestation.Platform(platform)
	if platformKey == "" {
		platformKey = attestation.PlatformDev
	}
	att, err := s.Attestation.Verify(ctx, platformKey, blob, devicePub, nonce)
	if err != nil {
		if errors.Is(err, attestation.ErrNonceMismatch) {
			return attestation.Attestation{}, status.Error(codes.FailedPrecondition, "attestation nonce mismatch")
		}
		if errors.Is(err, attestation.ErrAttestationFailed) {
			return attestation.Attestation{}, status.Errorf(codes.Unauthenticated, "attestation rejected: %v", err)
		}
		return attestation.Attestation{}, status.Errorf(codes.Internal, "attestation verify: %v", err)
	}
	return att, nil
}

// RegisterDevice registers a brand-new device+user pair.
//
// user_id MUST be supplied by the caller (the flow: caller phones KYC service
// out-of-band, receives a user id, then registers their device here). If the
// user id doesn't yet exist we create a minimal TIER_0 user record with
// placeholder profile fields so subsequent RPCs (e.g. FundOffline) have an
// accounts fan-out. Real signups come through the BFF /v1/auth/signup.
//
// This RPC is on the auth allow-list — a fresh device has no JWT yet.
func (s *RegistrationServer) RegisterDevice(ctx context.Context, req *pb.RegisterDeviceRequest) (*pb.RegisterDeviceResponse, error) {
	if req.GetUserId() == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	if len(req.GetDevicePublicKey()) == 0 {
		return nil, status.Error(codes.InvalidArgument, "device_public_key required")
	}

	if _, err := s.verifyAttestation(ctx, req.GetUserId(), req.GetPlatform(), req.GetAttestationBlob(), req.GetAttestationNonce(), req.GetDevicePublicKey()); err != nil {
		return nil, err
	}

	if err := s.Repo.RegisterUserWithID(ctx, req.GetUserId(), "", "", "", "TIER_0", 1); err != nil {
		if !pgrepo.IsUniqueViolation(err) {
			return nil, status.Errorf(codes.Internal, "register user: %v", err)
		}
	}

	// Idempotent re-register: a client reinstall that rehydrates its
	// keystore-backed keypair legitimately lands here. If the user
	// already has an active device with the same public key, return
	// that id rather than tripping uq_device_one_active_per_user. A
	// *different* active public key is treated as an implicit rotate —
	// the most common cause is a reinstall / cleared keystore where the
	// client can't sign a formal RotateDevice request, and the incoming
	// attestation nonce has already proven liveness of the new key.
	existing, err := s.Repo.GetActiveDeviceForUser(ctx, req.GetUserId())
	switch {
	case err == nil:
		if bytes.Equal(existing.PublicKey, req.GetDevicePublicKey()) {
			return &pb.RegisterDeviceResponse{
				DeviceId:        existing.ID,
				DeviceJwt:       "",
				RegisteredAt:    timestamppb.New(time.Now().UTC()),
				RealmKeyVersion: 1,
			}, nil
		}
	case errors.Is(err, pgx.ErrNoRows):
		// No active device — fall through to insert.
	default:
		return nil, status.Errorf(codes.Internal, "lookup active device: %v", err)
	}

	var deviceID string
	txErr := s.Repo.Tx(ctx, func(tx *pgrepo.Repo) error {
		if existing.ID != "" {
			if err := tx.DeactivateDevice(ctx, existing.ID); err != nil {
				return err
			}
		}
		if err := tx.SetUserPayerPubkey(ctx, req.GetUserId(), req.GetDevicePublicKey()); err != nil {
			return err
		}
		id, err := tx.RegisterDevice(ctx, req.GetUserId(), req.GetAttestationBlob(), req.GetDevicePublicKey())
		if err != nil {
			return err
		}
		deviceID = id
		return nil
	})
	if txErr != nil {
		return nil, status.Errorf(codes.Internal, "register device: %v", txErr)
	}
	return &pb.RegisterDeviceResponse{
		DeviceId:        deviceID,
		DeviceJwt:       "",
		RegisteredAt:    timestamppb.New(time.Now().UTC()),
		RealmKeyVersion: 1,
	}, nil
}

// Attest is an allow-listed liveness/confidence check. Real attestation
// (Play Integrity / DeviceCheck) lives in the Recovery gate or a future C-05.
// JWTs are minted client-side in this model, so this RPC does not issue one.
func (s *RegistrationServer) Attest(ctx context.Context, req *pb.AttestRequest) (*pb.AttestResponse, error) {
	return &pb.AttestResponse{
		Valid:     true,
		DeviceJwt: "",
		ExpiresAt: timestamppb.New(time.Now().UTC().Add(24 * time.Hour)),
	}, nil
}

// Deactivate is a lightweight self-service wrapper — the caller must be
// authenticated as the device being deactivated (or an active device on the
// same user). Prefer RevokeDevice for the "revoke-another-device" flow.
func (s *RegistrationServer) Deactivate(ctx context.Context, req *pb.DeactivateRequest) (*pb.DeactivateResponse, error) {
	authed, err := MustAuthUser(ctx)
	if err != nil {
		return nil, err
	}
	target := req.GetDeviceId()
	if target == "" {
		target = authed.DeviceID
	}
	if err := s.assertDeviceBelongsToUser(ctx, target, authed.UserID); err != nil {
		return nil, err
	}
	if err := s.Repo.DeactivateDevice(ctx, target); err != nil {
		return nil, status.Errorf(codes.Internal, "deactivate: %v", err)
	}
	return &pb.DeactivateResponse{DeactivatedAt: timestamppb.Now()}, nil
}

// RotateDevice swaps the caller's current device for a fresh keypair. Must
// be called from the OLD device (JWT signed by old device's key). Atomically:
//
//  1. Deactivate old device (flips `active=false`; the partial unique index
//     then permits a second active row for the same user).
//  2. Insert new device row as active.
//  3. Update users.payer_pubkey so future ceiling issuance uses the new key.
//
// Offline payment tokens already signed by the old key remain verifiable
// because each ceiling token carries the payer pubkey at issuance time
// (see wallet.Service.FundOffline — PayerPublicKey is captured into the
// ceiling, not re-resolved at settlement).
func (s *RegistrationServer) RotateDevice(ctx context.Context, req *pb.RotateDeviceRequest) (*pb.RotateDeviceResponse, error) {
	authed, err := MustMatchUser(ctx, req.GetUserId())
	if err != nil {
		return nil, err
	}
	if len(req.GetNewDevicePublicKey()) == 0 {
		return nil, status.Error(codes.InvalidArgument, "new_device_public_key required")
	}
	oldID := req.GetOldDeviceId()
	if oldID == "" {
		oldID = authed.DeviceID
	}
	if oldID != authed.DeviceID {
		// RotateDevice must be initiated from the device being replaced. If
		// the caller is a different device on the same user, they should use
		// RevokeDevice instead — the semantics (forcibly retire another
		// device) are different and want an explicit audit path.
		return nil, status.Error(codes.PermissionDenied, "rotate must originate from old device")
	}

	var newID string
	txErr := s.Repo.Tx(ctx, func(tx *pgrepo.Repo) error {
		if err := tx.DeactivateDevice(ctx, oldID); err != nil {
			return err
		}
		if err := tx.SetUserPayerPubkey(ctx, authed.UserID, req.GetNewDevicePublicKey()); err != nil {
			return err
		}
		id, err := tx.RegisterDevice(ctx, authed.UserID, req.GetAttestationBlob(), req.GetNewDevicePublicKey())
		if err != nil {
			return err
		}
		newID = id
		return nil
	})
	if txErr != nil {
		return nil, status.Errorf(codes.Internal, "rotate device: %v", txErr)
	}
	return &pb.RotateDeviceResponse{
		NewDeviceId:     newID,
		DeviceJwt:       "",
		RotatedAt:       timestamppb.Now(),
		RealmKeyVersion: 1,
	}, nil
}

// RevokeDevice marks another device on the same user account inactive. Used
// when the user suspects a secondary device is compromised. The caller must
// be authenticated as a *different* active device on the same user — the
// handler enforces that constraint. The revoked device's JWTs stop
// validating on the next RPC (interceptor rejects inactive devices).
func (s *RegistrationServer) RevokeDevice(ctx context.Context, req *pb.RevokeDeviceRequest) (*pb.RevokeDeviceResponse, error) {
	authed, err := MustAuthUser(ctx)
	if err != nil {
		return nil, err
	}
	if req.GetDeviceId() == "" {
		return nil, status.Error(codes.InvalidArgument, "device_id required")
	}
	if req.GetDeviceId() == authed.DeviceID {
		return nil, status.Error(codes.InvalidArgument, "cannot revoke own device — use RotateDevice")
	}
	if err := s.assertDeviceBelongsToUser(ctx, req.GetDeviceId(), authed.UserID); err != nil {
		return nil, err
	}
	if err := s.Repo.DeactivateDevice(ctx, req.GetDeviceId()); err != nil {
		return nil, status.Errorf(codes.Internal, "revoke device: %v", err)
	}
	return &pb.RevokeDeviceResponse{RevokedAt: timestamppb.Now()}, nil
}

// RecoverDevice provisions a replacement device when the user has lost
// access to their prior device. Allow-listed (the user has no JWT). Gated
// by RecoveryGate — production deployments must wire an OTP or KYC check.
//
// Mechanically does the same DB transitions as RotateDevice: deactivate
// whatever active device exists, insert a new active one, point
// users.payer_pubkey at the new key.
func (s *RegistrationServer) RecoverDevice(ctx context.Context, req *pb.RecoverDeviceRequest) (*pb.RecoverDeviceResponse, error) {
	if req.GetUserId() == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	if len(req.GetNewDevicePublicKey()) == 0 {
		return nil, status.Error(codes.InvalidArgument, "new_device_public_key required")
	}
	if err := s.Recovery.Verify(ctx, req.GetUserId(), req.GetRecoveryProof()); err != nil {
		return nil, err
	}

	var newID string
	txErr := s.Repo.Tx(ctx, func(tx *pgrepo.Repo) error {
		if prior, err := tx.GetActiveDeviceForUser(ctx, req.GetUserId()); err == nil && prior.ID != "" {
			if err := tx.DeactivateDevice(ctx, prior.ID); err != nil {
				return err
			}
		}
		if err := tx.SetUserPayerPubkey(ctx, req.GetUserId(), req.GetNewDevicePublicKey()); err != nil {
			return err
		}
		id, err := tx.RegisterDevice(ctx, req.GetUserId(), req.GetAttestationBlob(), req.GetNewDevicePublicKey())
		if err != nil {
			return err
		}
		newID = id
		return nil
	})
	if txErr != nil {
		return nil, status.Errorf(codes.Internal, "recover device: %v", txErr)
	}
	return &pb.RecoverDeviceResponse{
		NewDeviceId:     newID,
		RecoveredAt:     timestamppb.Now(),
		RealmKeyVersion: 1,
	}, nil
}

// assertDeviceBelongsToUser is the ownership guard used by Deactivate and
// RevokeDevice — a user can only alter their own devices.
func (s *RegistrationServer) assertDeviceBelongsToUser(ctx context.Context, deviceID, userID string) error {
	ownerID, _, _, err := s.Repo.LookupDeviceForAuth(ctx, deviceID)
	if err != nil {
		return status.Error(codes.NotFound, "device not found")
	}
	if ownerID != userID {
		return status.Error(codes.PermissionDenied, "device belongs to a different user")
	}
	return nil
}
