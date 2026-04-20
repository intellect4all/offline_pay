package bff

import (
	"context"
	"errors"

	"github.com/intellect/offlinepay/internal/service/userauth"
	bffgen "github.com/intellect/offlinepay/internal/transport/http/bff/gen"
)

// PostV1AuthDeviceSession mints an Ed25519-signed device session token the
// caller's app can verify locally to gate the offline wallet UX without
// connectivity. The caller's bearer token must be live; the device id in
// the body must be a registered, active device owned by the same user.
func (h *Handler) PostV1AuthDeviceSession(ctx context.Context, req bffgen.PostV1AuthDeviceSessionRequestObject) (bffgen.PostV1AuthDeviceSessionResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.PostV1AuthDeviceSession401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil || req.Body.DeviceId == "" {
		return bffgen.PostV1AuthDeviceSession400JSONResponse{Code: "bad_request", Message: "device_id required"}, nil
	}
	scope := ""
	if req.Body.Scope != nil {
		scope = string(*req.Body.Scope)
	}
	tok, err := h.Auth.IssueDeviceSession(ctx, claims.Sub, req.Body.DeviceId, claims.Sid, scope)
	if err != nil {
		switch {
		case errors.Is(err, userauth.ErrDeviceSessionUnav):
			return bffgen.PostV1AuthDeviceSession400JSONResponse{Code: "device_session_disabled", Message: "device session signer not configured"}, nil
		case errors.Is(err, userauth.ErrUnsupportedScope):
			return bffgen.PostV1AuthDeviceSession400JSONResponse{Code: "unsupported_scope", Message: "scope not supported"}, nil
		case errors.Is(err, userauth.ErrDeviceUnknown):
			return bffgen.PostV1AuthDeviceSession403JSONResponse{Code: "device_unknown", Message: "device not registered"}, nil
		case errors.Is(err, userauth.ErrDeviceNotOwned):
			return bffgen.PostV1AuthDeviceSession403JSONResponse{Code: "device_not_owned", Message: "device not owned by caller"}, nil
		case errors.Is(err, userauth.ErrDeviceInactive):
			return bffgen.PostV1AuthDeviceSession403JSONResponse{Code: "device_inactive", Message: "device deactivated"}, nil
		}
		h.Logger.Error("auth.device_session.issue", "err", err)
		return nil, err
	}
	scopeOut := bffgen.DeviceSessionResponseScope(tok.Scope)
	return bffgen.PostV1AuthDeviceSession200JSONResponse{
		Token:           tok.Token,
		ServerPublicKey: tok.ServerPublicKey,
		KeyId:           tok.KeyID,
		IssuedAt:        tok.IssuedAt,
		ExpiresAt:       tok.ExpiresAt,
		Scope:           scopeOut,
	}, nil
}

// GetV1AuthDeviceSessionPublicKeys returns the active Ed25519 public key
// bundle. Unauthenticated by design — the device may need it before its
// access token is fresh, and the keys are public material anyway.
func (h *Handler) GetV1AuthDeviceSessionPublicKeys(ctx context.Context, _ bffgen.GetV1AuthDeviceSessionPublicKeysRequestObject) (bffgen.GetV1AuthDeviceSessionPublicKeysResponseObject, error) {
	rows := h.Auth.ListDeviceSessionPublicKeys(ctx)
	out := make([]bffgen.DeviceSessionPublicKey, 0, len(rows))
	for _, r := range rows {
		entry := bffgen.DeviceSessionPublicKey{
			KeyId:      r.KeyID,
			PublicKey:  r.PublicKey,
			ActiveFrom: r.ActiveFrom,
		}
		if r.RetiredAt != nil {
			entry.RetiredAt = r.RetiredAt
		}
		out = append(out, entry)
	}
	return bffgen.GetV1AuthDeviceSessionPublicKeys200JSONResponse{Keys: out}, nil
}
