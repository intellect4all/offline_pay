package bff

import (
	"context"
	"errors"

	"github.com/intellect/offlinepay/internal/service/userauth"
	bffgen "github.com/intellect/offlinepay/internal/transport/http/bff/gen"
)

// PostV1AuthPin stores a transaction PIN for the authenticated user. The
// PIN itself is bcrypt-hashed inside userauth.SetPIN; it is never logged,
// echoed in responses, or persisted in plaintext.
func (h *Handler) PostV1AuthPin(ctx context.Context, req bffgen.PostV1AuthPinRequestObject) (bffgen.PostV1AuthPinResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.PostV1AuthPin401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1AuthPin400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	// claims.Sid is passed through so SetPIN's session-revocation sweep
	// preserves the caller's own session and evicts every other device.
	if err := h.Auth.SetPIN(ctx, claims.Sub, req.Body.Pin, claims.Sid); err != nil {
		if errors.Is(err, userauth.ErrInvalidPIN) {
			return bffgen.PostV1AuthPin400JSONResponse{Code: "invalid_pin", Message: "pin must be 4 or 6 digits"}, nil
		}
		if errors.Is(err, userauth.ErrUserNotFound) {
			return bffgen.PostV1AuthPin401JSONResponse{Code: "unauthorized", Message: "user not found"}, nil
		}
		h.Logger.Error("auth.pin.set", "err", err)
		return nil, err
	}
	return bffgen.PostV1AuthPin204Response{}, nil
}
