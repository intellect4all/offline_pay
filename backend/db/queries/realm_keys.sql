-- Realm key (Layer 1 AES-256 QR encryption) lifecycle. Rotation mints
-- a new version, retires the prior one with a grace-window overlap,
-- and GCs anything past its overlap. QRs sealed under a GC'd version
-- are accepted as undecryptable — the grace window is the design.

-- name: CreateRealmKey :one
INSERT INTO realm_keys (version, key_enc, active_from)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetRealmKey :one
SELECT * FROM realm_keys WHERE version = $1;

-- name: GetActiveRealmKey :one
SELECT * FROM realm_keys
WHERE retired_at IS NULL
ORDER BY active_from DESC
LIMIT 1;

-- ListActiveRealmKeys returns every key still inside its overlap
-- window — not yet retired, or retired with retired_at in the future.
-- Clients fetch the full set so a device can decrypt a backlog of QRs
-- sealed under any version still in overlap. Newest first.
--
-- name: ListActiveRealmKeys :many
SELECT * FROM realm_keys
WHERE retired_at IS NULL OR retired_at > now()
ORDER BY version DESC
LIMIT $1;

-- DeleteExpiredRealmKeys hard-deletes any key whose retired_at has
-- elapsed. Used by the rotate-realm-key ops command to GC keys past
-- their overlap window.
--
-- name: DeleteExpiredRealmKeys :exec
DELETE FROM realm_keys
WHERE retired_at IS NOT NULL AND retired_at <= now();

-- name: RetireRealmKey :exec
UPDATE realm_keys SET retired_at = $2 WHERE version = $1;

-- NextRealmKeyVersion returns max(version)+1 for minting a fresh key.
-- opsctl rotate-realm-key runs this inside the rotation tx.
--
-- name: NextRealmKeyVersion :one
SELECT COALESCE(MAX(version), 0) + 1 AS next_version FROM realm_keys;

-- RetireOtherRealmKeys stamps retired_at on every still-active row
-- whose version differs from $1. opsctl invokes this right after
-- inserting the newly minted key.
--
-- name: RetireOtherRealmKeys :exec
UPDATE realm_keys
SET retired_at = $2
WHERE retired_at IS NULL AND version <> $1;

-- DeleteRetiredRealmKeysBefore hard-deletes any row whose retired_at
-- is already past the supplied cutoff. Pairs with opsctl's prune step.
--
-- name: DeleteRetiredRealmKeysBefore :exec
DELETE FROM realm_keys
WHERE retired_at IS NOT NULL AND retired_at < $1;
