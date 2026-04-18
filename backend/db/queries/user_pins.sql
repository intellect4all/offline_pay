-- Per-user transaction PIN. user_pins is 1:1 with users; the row is
-- created on first PIN-set and refreshed via UPSERT on subsequent
-- resets.

-- SetUserPIN stores a freshly-hashed PIN and clears any prior lockout.
-- Returns rows-affected (always 1 after the upsert) so the caller can
-- confirm the write landed.
--
-- name: SetUserPIN :execrows
INSERT INTO user_pins (user_id, pin_hash, attempts, locked_at, updated_at)
VALUES ($1, $2, 0, NULL, now())
ON CONFLICT (user_id) DO UPDATE
SET pin_hash   = EXCLUDED.pin_hash,
    attempts   = 0,
    locked_at  = NULL,
    updated_at = now();

-- GetUserPINState returns the VerifyPIN projection. No row means the
-- user has not set a PIN yet; the service maps that to "pin_not_set".
--
-- name: GetUserPINState :one
SELECT pin_hash, attempts, locked_at
FROM user_pins
WHERE user_id = $1;

-- BumpPINAttempts records a mismatch below the lockout threshold.
--
-- name: BumpPINAttempts :exec
UPDATE user_pins
SET attempts   = $2,
    updated_at = now()
WHERE user_id = $1;

-- LockUserPIN records the mismatch that crosses the lockout threshold
-- and latches locked_at.
--
-- name: LockUserPIN :exec
UPDATE user_pins
SET attempts   = $2,
    locked_at  = now(),
    updated_at = now()
WHERE user_id = $1;

-- ClearUserPINAttempts zeros the counter on a successful verify. The
-- guard in the WHERE clause skips the write when the row is already
-- clean, avoiding an unnecessary heap touch on every login.
--
-- name: ClearUserPINAttempts :exec
UPDATE user_pins
SET attempts   = 0,
    locked_at  = NULL,
    updated_at = now()
WHERE user_id = $1 AND (attempts <> 0 OR locked_at IS NOT NULL);
