package bff

import (
	"context"
	"net/http"

	offlinepayv1 "github.com/intellect/offlinepay/internal/transport/grpc/gen/offlinepay/v1"
	bffgen "github.com/intellect/offlinepay/internal/transport/http/bff/gen"
)

func (h *Handler) PostV1DevicesAttestationChallenge(ctx context.Context, _ bffgen.PostV1DevicesAttestationChallengeRequestObject) (bffgen.PostV1DevicesAttestationChallengeResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1DevicesAttestationChallenge401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Registration.GetAttestationChallenge(ctx, &offlinepayv1.GetAttestationChallengeRequest{UserId: claims.Sub})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("registration.get_attestation_challenge", "code", code, "err", err)
		if statusCode == http.StatusUnauthorized {
			return bffgen.PostV1DevicesAttestationChallenge401JSONResponse{Code: code, Message: msg}, nil
		}
		return bffgen.PostV1DevicesAttestationChallenge502JSONResponse{Code: code, Message: msg}, nil
	}
	return bffgen.PostV1DevicesAttestationChallenge200JSONResponse{
		Nonce:     resp.GetNonce(),
		ExpiresAt: tsToTime(resp.GetExpiresAt()),
	}, nil
}

func (h *Handler) PostV1Devices(ctx context.Context, req bffgen.PostV1DevicesRequestObject) (bffgen.PostV1DevicesResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1Devices401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1Devices400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Registration.RegisterDevice(ctx, &offlinepayv1.RegisterDeviceRequest{
		UserId:           claims.Sub,
		DevicePublicKey:  req.Body.DevicePublicKey,
		Platform:         req.Body.Platform,
		AttestationBlob:  req.Body.AttestationBlob,
		AppVersion:       req.Body.AppVersion,
		AttestationNonce: req.Body.AttestationNonce,
	})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("registration.register_device", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.PostV1Devices400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusUnauthorized:
			return bffgen.PostV1Devices401JSONResponse{Code: code, Message: msg}, nil
		case http.StatusConflict:
			return bffgen.PostV1Devices409JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1Devices502JSONResponse{Code: code, Message: msg}, nil
		}
	}
	return bffgen.PostV1Devices200JSONResponse{
		DeviceId:        resp.GetDeviceId(),
		DeviceJwt:       resp.GetDeviceJwt(),
		RegisteredAt:    tsToTime(resp.GetRegisteredAt()),
		RealmKeyVersion: resp.GetRealmKeyVersion(),
	}, nil
}

func (h *Handler) PostV1DevicesDeviceIdAttest(ctx context.Context, req bffgen.PostV1DevicesDeviceIdAttestRequestObject) (bffgen.PostV1DevicesDeviceIdAttestResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1DevicesDeviceIdAttest401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1DevicesDeviceIdAttest400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Registration.Attest(ctx, &offlinepayv1.AttestRequest{
		DeviceId:        req.DeviceId,
		AttestationBlob: req.Body.AttestationBlob,
		Nonce:           req.Body.Nonce,
	})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("registration.attest", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.PostV1DevicesDeviceIdAttest400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusUnauthorized:
			return bffgen.PostV1DevicesDeviceIdAttest401JSONResponse{Code: code, Message: msg}, nil
		case http.StatusNotFound:
			return bffgen.PostV1DevicesDeviceIdAttest404JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1DevicesDeviceIdAttest502JSONResponse{Code: code, Message: msg}, nil
		}
	}
	out := bffgen.PostV1DevicesDeviceIdAttest200JSONResponse{
		Valid:     resp.GetValid(),
		DeviceJwt: resp.GetDeviceJwt(),
		ExpiresAt: tsToTime(resp.GetExpiresAt()),
	}
	if reason := resp.GetFailureReason(); reason != "" {
		out.FailureReason = &reason
	}
	return out, nil
}

func (h *Handler) PostV1DevicesDeviceIdDeactivate(ctx context.Context, req bffgen.PostV1DevicesDeviceIdDeactivateRequestObject) (bffgen.PostV1DevicesDeviceIdDeactivateResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1DevicesDeviceIdDeactivate401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1DevicesDeviceIdDeactivate400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Registration.Deactivate(ctx, &offlinepayv1.DeactivateRequest{
		DeviceId: req.DeviceId,
		UserId:   claims.Sub,
		Reason:   req.Body.Reason,
	})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("registration.deactivate", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.PostV1DevicesDeviceIdDeactivate400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusUnauthorized:
			return bffgen.PostV1DevicesDeviceIdDeactivate401JSONResponse{Code: code, Message: msg}, nil
		case http.StatusForbidden:
			return bffgen.PostV1DevicesDeviceIdDeactivate403JSONResponse{Code: code, Message: msg}, nil
		case http.StatusNotFound:
			return bffgen.PostV1DevicesDeviceIdDeactivate404JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1DevicesDeviceIdDeactivate502JSONResponse{Code: code, Message: msg}, nil
		}
	}
	return bffgen.PostV1DevicesDeviceIdDeactivate200JSONResponse{
		DeactivatedAt: tsToTime(resp.GetDeactivatedAt()),
	}, nil
}

func (h *Handler) PostV1DevicesRotate(ctx context.Context, req bffgen.PostV1DevicesRotateRequestObject) (bffgen.PostV1DevicesRotateResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1DevicesRotate401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1DevicesRotate400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Registration.RotateDevice(ctx, &offlinepayv1.RotateDeviceRequest{
		UserId:             claims.Sub,
		OldDeviceId:        req.Body.OldDeviceId,
		NewDevicePublicKey: req.Body.NewDevicePublicKey,
		Platform:           req.Body.Platform,
		AttestationBlob:    req.Body.AttestationBlob,
		AppVersion:         req.Body.AppVersion,
	})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("registration.rotate_device", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.PostV1DevicesRotate400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusUnauthorized:
			return bffgen.PostV1DevicesRotate401JSONResponse{Code: code, Message: msg}, nil
		case http.StatusConflict:
			return bffgen.PostV1DevicesRotate409JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1DevicesRotate502JSONResponse{Code: code, Message: msg}, nil
		}
	}
	return bffgen.PostV1DevicesRotate200JSONResponse{
		NewDeviceId:     resp.GetNewDeviceId(),
		DeviceJwt:       resp.GetDeviceJwt(),
		RotatedAt:       tsToTime(resp.GetRotatedAt()),
		RealmKeyVersion: resp.GetRealmKeyVersion(),
	}, nil
}

func (h *Handler) PostV1DevicesDeviceIdRevoke(ctx context.Context, req bffgen.PostV1DevicesDeviceIdRevokeRequestObject) (bffgen.PostV1DevicesDeviceIdRevokeResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1DevicesDeviceIdRevoke401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1DevicesDeviceIdRevoke400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Registration.RevokeDevice(ctx, &offlinepayv1.RevokeDeviceRequest{
		DeviceId: req.DeviceId,
		Reason:   req.Body.Reason,
	})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("registration.revoke_device", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.PostV1DevicesDeviceIdRevoke400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusUnauthorized:
			return bffgen.PostV1DevicesDeviceIdRevoke401JSONResponse{Code: code, Message: msg}, nil
		case http.StatusForbidden:
			return bffgen.PostV1DevicesDeviceIdRevoke403JSONResponse{Code: code, Message: msg}, nil
		case http.StatusNotFound:
			return bffgen.PostV1DevicesDeviceIdRevoke404JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1DevicesDeviceIdRevoke502JSONResponse{Code: code, Message: msg}, nil
		}
	}
	return bffgen.PostV1DevicesDeviceIdRevoke200JSONResponse{
		RevokedAt: tsToTime(resp.GetRevokedAt()),
	}, nil
}

func (h *Handler) PostV1DevicesRecover(ctx context.Context, req bffgen.PostV1DevicesRecoverRequestObject) (bffgen.PostV1DevicesRecoverResponseObject, error) {
	if req.Body == nil {
		return bffgen.PostV1DevicesRecover400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	resp, err := h.Registration.RecoverDevice(ctx, &offlinepayv1.RecoverDeviceRequest{
		UserId:             req.Body.UserId,
		RecoveryProof:      req.Body.RecoveryProof,
		NewDevicePublicKey: req.Body.NewDevicePublicKey,
		Platform:           req.Body.Platform,
		AttestationBlob:    req.Body.AttestationBlob,
		AppVersion:         req.Body.AppVersion,
	})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("registration.recover_device", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.PostV1DevicesRecover400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusForbidden:
			return bffgen.PostV1DevicesRecover403JSONResponse{Code: code, Message: msg}, nil
		case http.StatusNotFound:
			return bffgen.PostV1DevicesRecover404JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1DevicesRecover502JSONResponse{Code: code, Message: msg}, nil
		}
	}
	return bffgen.PostV1DevicesRecover200JSONResponse{
		NewDeviceId:     resp.GetNewDeviceId(),
		RecoveredAt:     tsToTime(resp.GetRecoveredAt()),
		RealmKeyVersion: resp.GetRealmKeyVersion(),
	}, nil
}

func (h *Handler) PostV1KeysBankPublicKeys(ctx context.Context, req bffgen.PostV1KeysBankPublicKeysRequestObject) (bffgen.PostV1KeysBankPublicKeysResponseObject, error) {
	var keyIDs []string
	if req.Body != nil && req.Body.KeyIds != nil {
		keyIDs = *req.Body.KeyIds
	}
	resp, err := h.Keys.GetBankPublicKeys(ctx, &offlinepayv1.GetBankPublicKeysRequest{KeyIds: keyIDs})
	if err != nil {
		_, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("keys.get_bank_public_keys", "code", code, "err", err)
		return bffgen.PostV1KeysBankPublicKeys502JSONResponse{Code: code, Message: msg}, nil
	}
	out := bffgen.PostV1KeysBankPublicKeys200JSONResponse{
		Keys: make([]bffgen.BankPublicKey, 0, len(resp.GetKeys())),
	}
	for _, k := range resp.GetKeys() {
		out.Keys = append(out.Keys, bankPublicKeyFromProto(k))
	}
	return out, nil
}

// assertRealmKeyDeviceOwnership verifies the caller owns an active device
// with the supplied device_id before we hand out the symmetric realm key.
// Returns a non-empty code ("unauthorized" | "bad_request") when the check
// fails; callers map that to the appropriate 4xx response.
func (h *Handler) assertRealmKeyDeviceOwnership(ctx context.Context, callerUserID, deviceID string) (code, msg string) {
	if deviceID == "" {
		return "bad_request", "device_id required"
	}
	userID, _, active, err := h.Keys.Repo.LookupDeviceForAuth(ctx, deviceID)
	if err != nil || userID == "" {
		// Unknown device — treat as unauthorized, never 404, so probing
		// the endpoint cannot enumerate device_ids.
		return "unauthorized", "device not found"
	}
	if userID != callerUserID {
		return "unauthorized", "device not owned by caller"
	}
	if !active {
		return "unauthorized", "device inactive"
	}
	return "", ""
}

func (h *Handler) GetV1KeysRealmVersion(ctx context.Context, req bffgen.GetV1KeysRealmVersionRequestObject) (bffgen.GetV1KeysRealmVersionResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.GetV1KeysRealmVersion401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if code, msg := h.assertRealmKeyDeviceOwnership(ctx, claims.Sub, req.Params.DeviceId); code != "" {
		if code == "bad_request" {
			return bffgen.GetV1KeysRealmVersion400JSONResponse{Code: code, Message: msg}, nil
		}
		return bffgen.GetV1KeysRealmVersion401JSONResponse{Code: code, Message: msg}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Keys.GetRealmKey(ctx, &offlinepayv1.GetRealmKeyRequest{
		Version:  req.Version,
		DeviceId: req.Params.DeviceId,
	})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("keys.get_realm_key", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.GetV1KeysRealmVersion400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusNotFound:
			return bffgen.GetV1KeysRealmVersion404JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.GetV1KeysRealmVersion502JSONResponse{Code: code, Message: msg}, nil
		}
	}
	return bffgen.GetV1KeysRealmVersion200JSONResponse{
		Version:    resp.GetVersion(),
		Key:        resp.GetKey(),
		ActiveFrom: tsToTime(resp.GetActiveFrom()),
		ExpiresAt:  tsToTime(resp.GetExpiresAt()),
	}, nil
}

func (h *Handler) GetV1KeysRealmActive(ctx context.Context, req bffgen.GetV1KeysRealmActiveRequestObject) (bffgen.GetV1KeysRealmActiveResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.GetV1KeysRealmActive401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if code, msg := h.assertRealmKeyDeviceOwnership(ctx, claims.Sub, req.Params.DeviceId); code != "" {
		if code == "bad_request" {
			return bffgen.GetV1KeysRealmActive400JSONResponse{Code: code, Message: msg}, nil
		}
		return bffgen.GetV1KeysRealmActive401JSONResponse{Code: code, Message: msg}, nil
	}
	var limit int32
	if req.Params.Limit != nil {
		limit = *req.Params.Limit
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Keys.GetActiveRealmKeys(ctx, &offlinepayv1.GetActiveRealmKeysRequest{
		DeviceId: req.Params.DeviceId,
		Limit:    limit,
	})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("keys.get_active_realm_keys", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.GetV1KeysRealmActive400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusUnauthorized:
			return bffgen.GetV1KeysRealmActive401JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.GetV1KeysRealmActive502JSONResponse{Code: code, Message: msg}, nil
		}
	}
	out := bffgen.GetV1KeysRealmActive200JSONResponse{
		Keys: make([]bffgen.RealmKey, 0, len(resp.GetKeys())),
	}
	for _, k := range resp.GetKeys() {
		out.Keys = append(out.Keys, realmKeyFromProto(k))
	}
	return out, nil
}

func (h *Handler) GetV1KeysSealedBoxPubkey(ctx context.Context, _ bffgen.GetV1KeysSealedBoxPubkeyRequestObject) (bffgen.GetV1KeysSealedBoxPubkeyResponseObject, error) {
	resp, err := h.Keys.GetServerSealedBoxPubkey(ctx, &offlinepayv1.GetServerSealedBoxPubkeyRequest{})
	if err != nil {
		_, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("keys.get_server_sealed_box_pubkey", "code", code, "err", err)
		return bffgen.GetV1KeysSealedBoxPubkey502JSONResponse{Code: code, Message: msg}, nil
	}
	return bffgen.GetV1KeysSealedBoxPubkey200JSONResponse{
		PublicKey:  resp.GetPublicKey(),
		KeyId:      resp.GetKeyId(),
		ActiveFrom: tsToTime(resp.GetActiveFrom()),
	}, nil
}
