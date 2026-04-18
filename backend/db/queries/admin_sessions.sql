-- Admin refresh-session storage. Login creates a session; rotation
-- inserts the replacement row and revokes the predecessor in one tx;
-- logout revokes by hash.

-- CreateAdminSession records a freshly issued refresh token at login.
-- user_agent + ip are captured for audit/session-list rendering.
--
-- name: CreateAdminSession :exec
INSERT INTO admin_sessions (id, admin_user_id, refresh_hash, user_agent, ip, expires_at)
VALUES ($1, $2, $3, $4, $5, $6);

-- CreateAdminSessionRotation records a post-refresh replacement
-- session. user_agent + ip are not re-captured on rotation; the
-- columns default to '' at the DB level.
--
-- name: CreateAdminSessionRotation :exec
INSERT INTO admin_sessions (id, admin_user_id, refresh_hash, expires_at)
VALUES ($1, $2, $3, $4);

-- GetAdminSessionByRefreshHash returns the refresh-validation
-- projection: the session id (to revoke on rotate), admin_user_id
-- (to reload roles), and the lifecycle timestamps (to detect expiry
-- and prior revocation).
--
-- name: GetAdminSessionByRefreshHash :one
SELECT id, admin_user_id, revoked_at, expires_at
FROM admin_sessions
WHERE refresh_hash = $1;

-- RevokeAdminSessionByID marks one session revoked. Used by the
-- rotate leg of Refresh when the id is already resolved.
--
-- name: RevokeAdminSessionByID :exec
UPDATE admin_sessions
SET revoked_at = now()
WHERE id = $1;

-- RevokeAdminSessionByHash is the logout path. The revoked_at IS NULL
-- guard keeps logout idempotent — repeat calls do nothing.
--
-- name: RevokeAdminSessionByHash :exec
UPDATE admin_sessions
SET revoked_at = now()
WHERE refresh_hash = $1 AND revoked_at IS NULL;
