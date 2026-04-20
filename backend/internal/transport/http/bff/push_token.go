package bff

import (
	"context"
	"strings"

	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
	bffgen "github.com/intellect/offlinepay/internal/transport/http/bff/gen"
)

// PostV1DevicesPushToken upserts the caller's FCM token so the settlement
// worker can fan transfer notifications out to this device.
func (h *Handler) PostV1DevicesPushToken(ctx context.Context, req bffgen.PostV1DevicesPushTokenRequestObject) (bffgen.PostV1DevicesPushTokenResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1DevicesPushToken401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1DevicesPushToken400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	token := strings.TrimSpace(req.Body.FcmToken)
	if token == "" {
		return bffgen.PostV1DevicesPushToken400JSONResponse{Code: "bad_request", Message: "fcm_token required"}, nil
	}

	q := sqlcgen.New(h.Pool)
	if err := q.UpsertPushToken(ctx, sqlcgen.UpsertPushTokenParams{
		FcmToken: token,
		UserID:   claims.Sub,
		Platform: string(req.Body.Platform),
	}); err != nil {
		h.Logger.Warn("push_token.upsert", "err", err)
		return bffgen.PostV1DevicesPushToken400JSONResponse{Code: "internal", Message: "could not store push token"}, nil
	}
	return bffgen.PostV1DevicesPushToken204Response{}, nil
}

// DeleteV1DevicesPushToken removes a token the client no longer owns (logout,
// token refresh). Scoped to the caller's user_id so one user cannot evict
// another's registration.
func (h *Handler) DeleteV1DevicesPushToken(ctx context.Context, req bffgen.DeleteV1DevicesPushTokenRequestObject) (bffgen.DeleteV1DevicesPushTokenResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.DeleteV1DevicesPushToken401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.DeleteV1DevicesPushToken400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	token := strings.TrimSpace(req.Body.FcmToken)
	if token == "" {
		return bffgen.DeleteV1DevicesPushToken400JSONResponse{Code: "bad_request", Message: "fcm_token required"}, nil
	}

	q := sqlcgen.New(h.Pool)
	if err := q.DeletePushToken(ctx, sqlcgen.DeletePushTokenParams{
		FcmToken: token,
		UserID:   claims.Sub,
	}); err != nil {
		h.Logger.Warn("push_token.delete", "err", err)
		return bffgen.DeleteV1DevicesPushToken400JSONResponse{Code: "internal", Message: "could not remove push token"}, nil
	}
	return bffgen.DeleteV1DevicesPushToken204Response{}, nil
}
