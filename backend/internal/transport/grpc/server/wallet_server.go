package server

import (
	"context"
	"errors"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
	"github.com/intellect/offlinepay/internal/service/wallet"
	pb "github.com/intellect/offlinepay/internal/transport/grpc/gen/offlinepay/v1"
)

// WalletServer implements pb.WalletServiceServer by delegating to
// service.wallet.Service.
type WalletServer struct {
	pb.UnimplementedWalletServiceServer

	Wallet *wallet.Service
	Repo   *pgrepo.Repo
}

// NewWalletServer constructs a WalletServer.
func NewWalletServer(ws *wallet.Service, repo *pgrepo.Repo) *WalletServer {
	return &WalletServer{Wallet: ws, Repo: repo}
}

// FundOffline debits main, places a lien, issues a ceiling token.
// If the request carries a payer public key, it is persisted first so that
// callers can register+fund in a single round trip (matches the Flutter
// client's registration-on-demand flow).
func (s *WalletServer) FundOffline(ctx context.Context, req *pb.FundOfflineRequest) (*pb.FundOfflineResponse, error) {
	if req.GetUserId() == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	if _, err := MustMatchUser(ctx, req.GetUserId()); err != nil {
		return nil, err
	}
	if req.GetAmountKobo() <= 0 {
		return nil, status.Error(codes.InvalidArgument, "amount_kobo must be positive")
	}
	if req.GetTtlSeconds() <= 0 {
		return nil, status.Error(codes.InvalidArgument, "ttl_seconds must be positive")
	}
	if len(req.GetPayerPublicKey()) > 0 {
		if err := s.Repo.SetUserPayerPubkey(ctx, req.GetUserId(), req.GetPayerPublicKey()); err != nil {
			return nil, status.Errorf(codes.Internal, "persist payer pubkey: %v", err)
		}
	}
	ttl := time.Duration(req.GetTtlSeconds()) * time.Second
	ct, err := s.Wallet.FundOffline(ctx, req.GetUserId(), req.GetAmountKobo(), ttl)
	if err != nil {
		return nil, fundOfflineErr(err)
	}
	return &pb.FundOfflineResponse{Ceiling: CeilingToProto(ct), LienId: ct.ID}, nil
}

// GetBalances returns the five per-user account balances.
func (s *WalletServer) GetBalances(ctx context.Context, req *pb.GetBalancesRequest) (*pb.GetBalancesResponse, error) {
	if req.GetUserId() == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	if _, err := MustMatchUser(ctx, req.GetUserId()); err != nil {
		return nil, err
	}
	b, err := s.Wallet.GetBalances(ctx, req.GetUserId())
	if err != nil {
		return nil, status.Errorf(codes.Internal, "balances: %v", err)
	}
	now := timestamppb.Now()
	mkBal := func(k sqlcgen.AccountKind, kobo int64) *pb.AccountBalance {
		return &pb.AccountBalance{
			Kind:        accountKindToProto(k),
			BalanceKobo: kobo,
			Currency:    "NGN",
			UpdatedAt:   now,
		}
	}
	return &pb.GetBalancesResponse{
		AsOf: now,
		Balances: []*pb.AccountBalance{
			mkBal(sqlcgen.AccountKindMain, b.Main),
			mkBal(sqlcgen.AccountKindLienHolding, b.LienHolding),
			mkBal(sqlcgen.AccountKindReceivingPending, b.ReceivingPending),
		},
	}, nil
}

// MoveToMain drains the offline wallet back to main.
func (s *WalletServer) MoveToMain(ctx context.Context, req *pb.MoveToMainRequest) (*pb.MoveToMainResponse, error) {
	if req.GetUserId() == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	if _, err := MustMatchUser(ctx, req.GetUserId()); err != nil {
		return nil, err
	}
	// Snapshot main balance pre+post so the response can return the delta.
	before, err := s.Wallet.GetBalances(ctx, req.GetUserId())
	if err != nil {
		return nil, status.Errorf(codes.Internal, "pre balance: %v", err)
	}
	if err := s.Wallet.MoveToMain(ctx, req.GetUserId()); err != nil {
		switch {
		case errors.Is(err, wallet.ErrNoActiveCeiling):
			return nil, status.Error(codes.FailedPrecondition, err.Error())
		case errors.Is(err, wallet.ErrUnsettledClaims):
			return nil, status.Error(codes.FailedPrecondition, err.Error())
		}
		return nil, status.Errorf(codes.Internal, "move to main: %v", err)
	}
	after, err := s.Wallet.GetBalances(ctx, req.GetUserId())
	if err != nil {
		return nil, status.Errorf(codes.Internal, "post balance: %v", err)
	}
	return &pb.MoveToMainResponse{
		ReleasedKobo:       after.Main - before.Main,
		NewMainBalanceKobo: after.Main,
	}, nil
}

// RefreshCeiling rotates the active ceiling.
func (s *WalletServer) RefreshCeiling(ctx context.Context, req *pb.RefreshCeilingRequest) (*pb.RefreshCeilingResponse, error) {
	if req.GetUserId() == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	if _, err := MustMatchUser(ctx, req.GetUserId()); err != nil {
		return nil, err
	}
	if req.GetNewAmountKobo() <= 0 {
		return nil, status.Error(codes.InvalidArgument, "new_amount_kobo must be positive")
	}
	if req.GetTtlSeconds() <= 0 {
		return nil, status.Error(codes.InvalidArgument, "ttl_seconds must be positive")
	}
	if len(req.GetPayerPublicKey()) > 0 {
		if err := s.Repo.SetUserPayerPubkey(ctx, req.GetUserId(), req.GetPayerPublicKey()); err != nil {
			return nil, status.Errorf(codes.Internal, "persist payer pubkey: %v", err)
		}
	}
	ttl := time.Duration(req.GetTtlSeconds()) * time.Second
	ct, err := s.Wallet.Refresh(ctx, req.GetUserId(), req.GetNewAmountKobo(), ttl)
	if err != nil {
		return nil, fundOfflineErr(err)
	}
	return &pb.RefreshCeilingResponse{Ceiling: CeilingToProto(ct), LienId: ct.ID}, nil
}

// RecoverOfflineCeilingRequest / Response are plain Go DTOs for the
// recover-offline-ceiling path. We don't add protobuf messages for them
// — the gRPC hop is gone and these types never cross a wire.
type RecoverOfflineCeilingRequest struct {
	UserID string
}

type RecoverOfflineCeilingResponse struct {
	CeilingID       string
	QuarantinedKobo int64
	ReleaseAfter    time.Time
}

// GetCurrentCeilingRequest / Response feed the BFF ceiling-status
// endpoint. Present = the payer has an ACTIVE or RECOVERY_PENDING
// ceiling; Absent = no offline wallet.
type GetCurrentCeilingRequest struct {
	UserID string
}

type GetCurrentCeilingResponse struct {
	Present       bool
	CeilingID     string
	Status        string
	CeilingKobo   int64
	SettledKobo   int64
	RemainingKobo int64
	IssuedAt      time.Time
	ExpiresAt     time.Time
	// ReleaseAfter is zero unless Status == RECOVERY_PENDING.
	ReleaseAfter time.Time
}

// RecoverOfflineCeiling initiates recovery of a ceiling whose device-side
// token was lost. See wallet.Service.RecoverOfflineCeiling for the
// full policy. Error codes mirror the FailedPrecondition shape used by
// MoveToMain / RefreshCeiling so the BFF error mapper stays uniform.
func (s *WalletServer) RecoverOfflineCeiling(ctx context.Context, req *RecoverOfflineCeilingRequest) (*RecoverOfflineCeilingResponse, error) {
	if req == nil || req.UserID == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	if _, err := MustMatchUser(ctx, req.UserID); err != nil {
		return nil, err
	}
	ct, err := s.Wallet.RecoverOfflineCeiling(ctx, req.UserID)
	if err != nil {
		switch {
		case errors.Is(err, wallet.ErrNoActiveCeiling):
			return nil, status.Error(codes.NotFound, err.Error())
		case errors.Is(err, wallet.ErrUnsettledClaims):
			return nil, status.Error(codes.FailedPrecondition, err.Error())
		case errors.Is(err, wallet.ErrRecoveryRaceLost):
			return nil, status.Error(codes.FailedPrecondition, err.Error())
		}
		return nil, status.Errorf(codes.Internal, "recover offline ceiling: %v", err)
	}
	releaseAfter := time.Time{}
	if ct.ReleaseAfter != nil {
		releaseAfter = *ct.ReleaseAfter
	}
	return &RecoverOfflineCeilingResponse{
		CeilingID:       ct.ID,
		QuarantinedKobo: ct.CeilingAmount,
		ReleaseAfter:    releaseAfter,
	}, nil
}

// GetCurrentCeiling returns the payer's latest non-terminal ceiling
// (ACTIVE or RECOVERY_PENDING) with derived settled + remaining fields
// so mobile can render the offline-wallet card in one round-trip.
// Always returns 200 with Present=false when the payer has no offline
// wallet — that's a legitimate tri-state, not an error.
func (s *WalletServer) GetCurrentCeiling(ctx context.Context, req *GetCurrentCeilingRequest) (*GetCurrentCeilingResponse, error) {
	if req == nil || req.UserID == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	if _, err := MustMatchUser(ctx, req.UserID); err != nil {
		return nil, err
	}
	cur, err := s.Wallet.GetCurrentCeiling(ctx, req.UserID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "get current ceiling: %v", err)
	}
	if cur == nil {
		return &GetCurrentCeilingResponse{Present: false}, nil
	}
	resp := &GetCurrentCeilingResponse{
		Present:       true,
		CeilingID:     cur.ID,
		Status:        string(cur.Status),
		CeilingKobo:   cur.CeilingKobo,
		SettledKobo:   cur.SettledKobo,
		RemainingKobo: cur.RemainingKobo,
		IssuedAt:      cur.IssuedAt,
		ExpiresAt:     cur.ExpiresAt,
	}
	if cur.ReleaseAfter != nil {
		resp.ReleaseAfter = *cur.ReleaseAfter
	}
	return resp, nil
}

func fundOfflineErr(err error) error {
	switch {
	case errors.Is(err, wallet.ErrActiveCeilingExists):
		return status.Error(codes.AlreadyExists, err.Error())
	case errors.Is(err, wallet.ErrInsufficientFunds):
		return status.Error(codes.FailedPrecondition, err.Error())
	case errors.Is(err, wallet.ErrMissingPayerPubkey):
		return status.Error(codes.FailedPrecondition, err.Error())
	case errors.Is(err, wallet.ErrUnsettledClaims):
		return status.Error(codes.FailedPrecondition, err.Error())
	case errors.Is(err, wallet.ErrNoActiveCeiling):
		return status.Error(codes.FailedPrecondition, err.Error())
	}
	return status.Errorf(codes.Internal, "%v", err)
}
