-- End-user auth storage: OTP challenges driving signup-email-verify
-- and password-reset, plus refresh-session CRUD for login/rotate/
-- logout. admin auth queries live in admin.sql / admin_sessions.sql
-- because admin_users is a separate identity surface.

-- UpsertOTPChallenge stores or replaces the single active challenge
-- per (identifier, purpose). A re-send resets attempts + expires_at
-- and clears consumed_at so the fresh code is usable.
--
-- name: UpsertOTPChallenge :exec
INSERT INTO otp_challenges (identifier, purpose, code_hash, expires_at)
VALUES ($1, $2, $3, $4)
ON CONFLICT (identifier, purpose) DO UPDATE
SET code_hash = EXCLUDED.code_hash,
    attempts = 0,
    created_at = now(),
    expires_at = EXCLUDED.expires_at,
    consumed_at = NULL;

-- name: GetOTPChallenge :one
SELECT identifier, code_hash, purpose, attempts, created_at, expires_at, consumed_at
FROM otp_challenges
WHERE identifier = $1 AND purpose = $2;

-- name: IncrementOTPAttempts :exec
UPDATE otp_challenges SET attempts = attempts + 1
WHERE identifier = $1 AND purpose = $2;

-- name: ConsumeOTPChallenge :exec
UPDATE otp_challenges SET consumed_at = now()
WHERE identifier = $1 AND purpose = $2;

-- name: CreateUserSession :exec
INSERT INTO user_sessions (id, user_id, refresh_hash, user_agent, ip, device_id, expires_at)
VALUES ($1, $2, $3, $4, $5, $6, $7);

-- CreateUserSessionRotation records the replacement refresh row after
-- a successful /auth/refresh. user_agent/ip/device_id are not
-- re-captured on rotation — the DB-level defaults ('' / NULL) apply.
--
-- name: CreateUserSessionRotation :exec
INSERT INTO user_sessions (id, user_id, refresh_hash, expires_at)
VALUES ($1, $2, $3, $4);

-- name: GetUserSessionByRefreshHash :one
SELECT s.id, s.user_id, s.expires_at, s.revoked_at
FROM user_sessions s
WHERE s.refresh_hash = $1;

-- name: RevokeUserSessionByHash :exec
UPDATE user_sessions SET revoked_at = now()
WHERE refresh_hash = $1 AND revoked_at IS NULL;

-- name: RevokeUserSessionByID :exec
UPDATE user_sessions SET revoked_at = now()
WHERE id = $1 AND revoked_at IS NULL;

-- ListActiveUserSessions returns every non-revoked, non-expired
-- refresh session for userID. Powers the end-user devices/sessions
-- screen.
--
-- name: ListActiveUserSessions :many
SELECT id, user_agent, ip, device_id, created_at, expires_at
FROM user_sessions
WHERE user_id = $1
  AND revoked_at IS NULL
  AND expires_at > now()
ORDER BY created_at DESC;

-- GetUserSessionOwner returns owner + revocation state for one
-- session id. RevokeSession uses this to enforce per-user ownership
-- before the revocation write.
--
-- name: GetUserSessionOwner :one
SELECT user_id, revoked_at FROM user_sessions WHERE id = $1;

-- RevokeOtherUserSessions revokes every active session for userID
-- except the one identified by $2. Pass '' in $2 to revoke all
-- sessions (the "sign me out everywhere" flow).
--
-- name: RevokeOtherUserSessions :execrows
UPDATE user_sessions
SET revoked_at = now()
WHERE user_id = $1
  AND revoked_at IS NULL
  AND id <> $2;
