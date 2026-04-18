-- Device registry. One active device per user is enforced at the
-- schema level (partial unique index); these queries own the lifecycle
-- (register, touch, deactivate) plus the admin read surface.

-- name: CreateDevice :one
INSERT INTO devices (id, user_id, attestation_blob, public_key, active, last_seen_at)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetDevice :one
SELECT * FROM devices WHERE id = $1;

-- name: GetActiveDeviceForUser :one
SELECT * FROM devices WHERE user_id = $1 AND active = TRUE;

-- name: DeactivateDevice :exec
UPDATE devices SET active = FALSE, updated_at = now() WHERE id = $1;

-- name: TouchDevice :exec
UPDATE devices SET last_seen_at = $2, updated_at = now() WHERE id = $1;

-- ListDevicesForAdmin returns the backoffice projection for one
-- user's devices, newest first. Narrow column set so the backoffice
-- payload stays stable independent of internal schema additions.
--
-- name: ListDevicesForAdmin :many
SELECT id,
       active,
       last_seen_at,
       created_at
FROM devices
WHERE user_id = $1
ORDER BY created_at DESC;
