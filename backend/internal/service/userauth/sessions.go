package userauth

import (
	"context"
	"errors"
	"time"

	"github.com/intellect/offlinepay/internal/repository/userauthrepo"
)

// Session-management errors. Exported so BFF handlers can map them to
// stable HTTP codes.
var (
	// ErrSessionNotFound covers both "no row with that id" and "row exists
	// but is not owned by the caller" — the 404 case either way, so we
	// don't leak cross-tenant existence.
	ErrSessionNotFound = errors.New("userauth: session not found")

	// ErrCannotRevokeCurrent is returned by RevokeSession when the target
	// id matches the caller's own sid. Callers should call Logout with
	// the refresh token instead; this keeps the access-token/refresh-token
	// pairing intact.
	ErrCannotRevokeCurrent = errors.New("userauth: cannot revoke current session")
)

// Session is a projection of the user_sessions row suitable for end-user
// listing. Never includes the refresh_hash.
type Session struct {
	ID        string
	UserAgent string
	IP        string
	DeviceID  *string
	CreatedAt time.Time
	ExpiresAt time.Time
}

// ListSessions returns every non-revoked, non-expired session row for
// userID, ordered by most recent first. An empty slice is returned if the
// user has none (never an error).
//
// Note on consistency: revoking a session only invalidates the refresh
// token. The access JWT issued from that session remains cryptographically
// valid until its Exp timestamp (access TTL ~15m). We accept this
// eventually-consistent window deliberately — a server-side access-JWT
// blacklist would demand every protected call hit Redis, and the short
// TTL already bounds the exposure. Refresh is the gated hop.
func (s *Service) ListSessions(ctx context.Context, userID string) ([]Session, error) {
	if userID == "" {
		return nil, errors.New("userauth: user_id required")
	}
	rows, err := s.Repo.ListActiveUserSessions(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]Session, 0, len(rows))
	for _, r := range rows {
		out = append(out, Session{
			ID:        r.ID,
			UserAgent: r.UserAgent,
			IP:        r.IP,
			DeviceID:  r.DeviceID,
			CreatedAt: r.CreatedAt,
			ExpiresAt: r.ExpiresAt,
		})
	}
	return out, nil
}

// RevokeSession marks a single session row revoked. The row must belong to
// userID; otherwise ErrSessionNotFound is returned (we don't distinguish
// "not yours" from "not there" in the API).
//
// Callers must not pass their own sid — this returns
// ErrCannotRevokeCurrent in that case. Revoking the current session would
// leave a valid access token in the caller's pocket with no paired
// refresh token; better to force them through Logout.
func (s *Service) RevokeSession(ctx context.Context, userID, sessionID, currentSessionID string) error {
	if userID == "" || sessionID == "" {
		return errors.New("userauth: user_id and session_id required")
	}
	if currentSessionID != "" && sessionID == currentSessionID {
		return ErrCannotRevokeCurrent
	}
	ownerID, revokedAt, err := s.Repo.GetUserSessionOwner(ctx, sessionID)
	if err != nil {
		if errors.Is(err, userauthrepo.ErrNotFound) {
			return ErrSessionNotFound
		}
		return err
	}
	if ownerID != userID {
		return ErrSessionNotFound
	}
	if revokedAt != nil {
		// Idempotent: already revoked is a no-op success.
		return nil
	}
	return s.Repo.RevokeUserSessionByID(ctx, sessionID)
}

// RevokeAllOtherSessions revokes every active session for userID except
// the one identified by keepSessionID. Returns the number of rows
// revoked. Passing an empty keepSessionID revokes ALL active sessions —
// callers typically don't want that; the BFF handler always passes
// claims.Sid.
func (s *Service) RevokeAllOtherSessions(ctx context.Context, userID, keepSessionID string) (int, error) {
	if userID == "" {
		return 0, errors.New("userauth: user_id required")
	}
	n, err := s.Repo.RevokeOtherUserSessions(ctx, userID, keepSessionID)
	if err != nil {
		return 0, err
	}
	return int(n), nil
}
