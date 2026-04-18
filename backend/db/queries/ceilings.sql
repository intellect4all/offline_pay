-- Ceiling-token CRUD + lifecycle transitions. Ceilings drive the
-- offline-spending authorisation budget; each payer can have at most
-- one live (ACTIVE or RECOVERY_PENDING) ceiling at a time.

-- name: CreateCeilingToken :one
INSERT INTO ceiling_tokens (
    id, payer_user_id, ceiling_kobo, sequence_start,
    issued_at, expires_at, payer_pubkey, bank_key_id, bank_sig,
    status, lien_account_id
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
RETURNING *;

-- name: GetCeilingToken :one
SELECT * FROM ceiling_tokens WHERE id = $1;

-- name: GetActiveCeilingForUser :one
SELECT * FROM ceiling_tokens
WHERE payer_user_id = $1 AND status = 'ACTIVE';

-- name: ListCeilingsByUser :many
SELECT * FROM ceiling_tokens
WHERE payer_user_id = $1
ORDER BY issued_at DESC;

-- name: UpdateCeilingStatus :exec
UPDATE ceiling_tokens SET status = $2 WHERE id = $1;

-- name: ListExpiredActiveCeilings :many
SELECT * FROM ceiling_tokens
WHERE status = 'ACTIVE' AND expires_at < $1;

-- ForceExpireActiveCeiling flips one ceiling to EXPIRED iff it is
-- currently ACTIVE. Used by opsctl force-expire-ceiling; returns
-- rows-affected so the caller can distinguish "id not found / already
-- terminal" from a real transition.
--
-- name: ForceExpireActiveCeiling :execrows
UPDATE ceiling_tokens
SET status = 'EXPIRED'
WHERE id = $1 AND status = 'ACTIVE';

-- ListCeilingsForAdmin returns the payer's most recent ceilings with
-- their live remaining balance (ceiling_kobo - SUM(settled across
-- attached payment_tokens)). Feeds the backoffice user-detail view.
--
-- name: ListCeilingsForAdmin :many
SELECT c.id,
       c.status::text                                         AS status,
       c.ceiling_kobo,
       (c.ceiling_kobo - COALESCE((
           SELECT SUM(settled_amount_kobo)
           FROM payment_tokens p
           WHERE p.ceiling_id = c.id
       ), 0))::BIGINT                                         AS remaining_kobo,
       c.issued_at,
       c.expires_at
FROM ceiling_tokens c
WHERE c.payer_user_id = $1
ORDER BY c.issued_at DESC
LIMIT $2;

-- ListReleasableExpiredCeilings picks up ceilings ready to be released
-- back to the main wallet:
--   1. ACTIVE ceilings past their grace window (normal expiry path).
--   2. RECOVERY_PENDING ceilings past release_after (recovery
--      quarantine elapsed).
-- Rows with in-flight payment claims are skipped — those funds are
-- legitimately owed and will be claimed by the merchant settlement.
--
-- name: ListReleasableExpiredCeilings :many
SELECT c.* FROM ceiling_tokens c
WHERE (
        (c.status = 'ACTIVE'            AND c.expires_at    < $1)
     OR (c.status = 'RECOVERY_PENDING'  AND c.release_after < $1)
      )
  AND NOT EXISTS (
    SELECT 1 FROM payment_tokens p
    WHERE p.ceiling_id = c.id
      AND p.status IN ('PENDING', 'SUBMITTED')
  );

-- MarkCeilingRecoveryPending transitions an ACTIVE ceiling into
-- RECOVERY_PENDING and stamps release_after. Returns rows-affected so
-- the caller can distinguish "no active ceiling", "already
-- recovering", and "success".
--
-- name: MarkCeilingRecoveryPending :execrows
UPDATE ceiling_tokens
SET status = 'RECOVERY_PENDING',
    release_after = $2
WHERE id = $1 AND status = 'ACTIVE';

-- GetCeilingRecoveryDetails returns the narrow projection the BFF
-- surfaces to the Flutter client while it polls recovery status.
-- status + release_after + ceiling_kobo are the client-rendered
-- fields; the remaining columns support the admin-side overlay.
--
-- name: GetCeilingRecoveryDetails :one
SELECT id, status::text AS status, ceiling_kobo, release_after,
       issued_at, expires_at
FROM ceiling_tokens
WHERE id = $1;

-- SumSettledForCeiling returns the total settled amount across every
-- payment token attached to this ceiling. releaseCeiling subtracts
-- this from ceiling_kobo to derive the remaining lien — attempting
-- to debit the full ceiling would trip the balance_kobo >= $amount
-- guard the moment any merchant claim has landed.
--
-- name: SumSettledForCeiling :one
SELECT COALESCE(SUM(settled_amount_kobo), 0)::BIGINT AS settled_kobo
FROM payment_tokens
WHERE ceiling_id = $1;

-- GetCurrentCeilingForPayer returns the payer's most recent non-
-- terminal ceiling with its live settled and remaining totals. The
-- Flutter client uses the single result to render the tri-state panel
-- (active / recovery_pending / none) in one round trip.
--
-- `remaining_kobo` = ceiling_kobo - SUM(settled across attached
-- payment tokens). Same math releaseCeiling uses to size the lien
-- release, so ops surfaces can cross-check against the lien balance.
--
-- name: GetCurrentCeilingForPayer :one
SELECT c.id,
       c.status::text       AS status,
       c.ceiling_kobo,
       COALESCE((
           SELECT SUM(settled_amount_kobo)
           FROM payment_tokens p
           WHERE p.ceiling_id = c.id
       ), 0)::BIGINT         AS settled_kobo,
       (c.ceiling_kobo - COALESCE((
           SELECT SUM(settled_amount_kobo)
           FROM payment_tokens p
           WHERE p.ceiling_id = c.id
       ), 0))::BIGINT        AS remaining_kobo,
       c.issued_at,
       c.expires_at,
       c.release_after
FROM ceiling_tokens c
WHERE c.payer_user_id = $1
  AND c.status IN ('ACTIVE', 'RECOVERY_PENDING')
ORDER BY c.issued_at DESC
LIMIT 1;
