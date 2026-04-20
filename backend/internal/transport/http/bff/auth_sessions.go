package bff

import (
	"context"
	"errors"

	"github.com/intellect/offlinepay/internal/service/userauth"
	bffgen "github.com/intellect/offlinepay/internal/transport/http/bff/gen"
)

// GetV1AuthSessions lists the caller's active refresh sessions. The row
// whose id matches claims.Sid is flagged is_current=true so the client UI
// can render "This device" and disable revoke on the current row.
func (h *Handler) GetV1AuthSessions(ctx context.Context, _ bffgen.GetV1AuthSessionsRequestObject) (bffgen.GetV1AuthSessionsResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.GetV1AuthSessions401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	sessions, err := h.Auth.ListSessions(ctx, claims.Sub)
	if err != nil {
		h.Logger.Error("auth.sessions.list", "err", err)
		return nil, err
	}
	items := make([]bffgen.Session, 0, len(sessions))
	for _, s := range sessions {
		items = append(items, bffgen.Session{
			Id:        s.ID,
			UserAgent: s.UserAgent,
			Ip:        s.IP,
			DeviceId:  s.DeviceID,
			CreatedAt: s.CreatedAt,
			ExpiresAt: s.ExpiresAt,
			IsCurrent: s.ID == claims.Sid,
		})
	}
	return bffgen.GetV1AuthSessions200JSONResponse{Items: items}, nil
}

// PostV1AuthSessionsIdRevoke revokes a single session belonging to the
// caller. Revoking the current session is rejected with 400
// cannot_revoke_current; clients should use POST /v1/auth/logout with the
// refresh token instead (which also clears the access/refresh pair on the
// client).
func (h *Handler) PostV1AuthSessionsIdRevoke(ctx context.Context, req bffgen.PostV1AuthSessionsIdRevokeRequestObject) (bffgen.PostV1AuthSessionsIdRevokeResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.PostV1AuthSessionsIdRevoke401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if err := h.Auth.RevokeSession(ctx, claims.Sub, req.Id, claims.Sid); err != nil {
		switch {
		case errors.Is(err, userauth.ErrCannotRevokeCurrent):
			return bffgen.PostV1AuthSessionsIdRevoke400JSONResponse{
				Code:    "cannot_revoke_current",
				Message: "use /v1/auth/logout to revoke the current session",
			}, nil
		case errors.Is(err, userauth.ErrSessionNotFound):
			return bffgen.PostV1AuthSessionsIdRevoke404JSONResponse{
				Code:    "session_not_found",
				Message: "session not found",
			}, nil
		}
		h.Logger.Error("auth.sessions.revoke", "err", err)
		return nil, err
	}
	return bffgen.PostV1AuthSessionsIdRevoke204Response{}, nil
}

// PostV1AuthSessionsRevokeAllOthers revokes every active session for the
// caller except the current one. Returns the number of rows revoked.
func (h *Handler) PostV1AuthSessionsRevokeAllOthers(ctx context.Context, _ bffgen.PostV1AuthSessionsRevokeAllOthersRequestObject) (bffgen.PostV1AuthSessionsRevokeAllOthersResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.PostV1AuthSessionsRevokeAllOthers401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	n, err := h.Auth.RevokeAllOtherSessions(ctx, claims.Sub, claims.Sid)
	if err != nil {
		h.Logger.Error("auth.sessions.revoke-all-others", "err", err)
		return nil, err
	}
	return bffgen.PostV1AuthSessionsRevokeAllOthers200JSONResponse{Revoked: int32(n)}, nil
}
