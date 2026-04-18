-- End-user Ed25519 signing keys. Only the active row's pubkey issues
-- new ceiling tokens; historical ceilings verify against the
-- snapshotted pubkey stored in ceiling_tokens.payer_pubkey, so
-- rotation never invalidates in-flight offline payments.

-- InsertSigningKey records a freshly-provisioned active key. Callers
-- must retire any previous active key (RetireActiveSigningKey) in
-- the same tx — the partial unique index enforces one active row
-- per user.
--
-- name: InsertSigningKey :one
INSERT INTO signing_keys (id, user_id, device_id, public_key, active)
VALUES ($1, $2, $3, $4, TRUE)
RETURNING *;

-- GetActiveSigningKey returns the user's currently active key.
--
-- name: GetActiveSigningKey :one
SELECT * FROM signing_keys
WHERE user_id = $1 AND active = TRUE;

-- GetActiveSigningKeyPubkey is the narrow hot-path lookup used at
-- ceiling-issue time. No row means the user has not registered a
-- signing key yet.
--
-- name: GetActiveSigningKeyPubkey :one
SELECT public_key FROM signing_keys
WHERE user_id = $1 AND active = TRUE;

-- RetireActiveSigningKey flips the active key to inactive and stamps
-- rotated_at. The first step of rotation; InsertSigningKey follows
-- inside the same tx.
--
-- name: RetireActiveSigningKey :exec
UPDATE signing_keys
SET active = FALSE,
    rotated_at = now()
WHERE user_id = $1 AND active = TRUE;

-- ListSigningKeysByUser returns rotation history newest first.
-- Powers the backoffice key-history view.
--
-- name: ListSigningKeysByUser :many
SELECT * FROM signing_keys
WHERE user_id = $1
ORDER BY created_at DESC;
