-- Bank-side Ed25519 signing keys. Rotation is "insert new, retire old";
-- historical ceilings verify against the snapshotted pubkey stored in
-- ceiling_tokens.payer_pubkey rather than the live row here.

-- name: CreateBankSigningKey :one
INSERT INTO bank_signing_keys (key_id, pubkey, privkey_enc, active_from)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: GetBankSigningKey :one
SELECT * FROM bank_signing_keys WHERE key_id = $1;

-- name: GetActiveBankSigningKey :one
SELECT * FROM bank_signing_keys
WHERE retired_at IS NULL
ORDER BY active_from DESC
LIMIT 1;

-- name: ListActiveBankSigningKeys :many
SELECT * FROM bank_signing_keys
WHERE retired_at IS NULL
ORDER BY active_from DESC;

-- name: RetireBankSigningKey :exec
UPDATE bank_signing_keys SET retired_at = $2 WHERE key_id = $1;

-- RetireAllActiveBankSigningKeys stamps retired_at on every still-active
-- row. Called by opsctl rotate-bank-key immediately before inserting
-- the freshly minted key so the new key is the only live one.
--
-- name: RetireAllActiveBankSigningKeys :exec
UPDATE bank_signing_keys
SET retired_at = $1
WHERE retired_at IS NULL;
