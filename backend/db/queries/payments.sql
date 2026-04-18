-- Payment-token CRUD + lifecycle updates, plus the admin/dashboard
-- projections that read across payment_tokens and transfers as one
-- unified money-movement feed.

-- name: CreatePaymentToken :one
INSERT INTO payment_tokens (
    id, ceiling_id, payer_user_id, payee_user_id,
    amount_kobo, sequence_number, remaining_ceiling_kobo,
    signed_at, payer_sig, status,
    session_nonce, request_hash, request_amount_kobo,
    submitted_by_user_id
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
RETURNING *;

-- name: GetPaymentToken :one
SELECT * FROM payment_tokens WHERE id = $1;

-- name: GetPaymentBySequence :one
SELECT * FROM payment_tokens
WHERE payer_user_id = $1 AND sequence_number = $2;

-- name: ListPaymentsByPayer :many
SELECT * FROM payment_tokens
WHERE payer_user_id = $1
ORDER BY sequence_number ASC;

-- name: ListPendingPaymentsByPayer :many
SELECT * FROM payment_tokens
WHERE payer_user_id = $1 AND status = 'PENDING'
ORDER BY sequence_number ASC;

-- name: ListPaymentsByPayee :many
SELECT * FROM payment_tokens
WHERE payee_user_id = $1
ORDER BY created_at DESC;

-- name: CountInFlightPaymentsForCeiling :one
SELECT COUNT(*) FROM payment_tokens
WHERE ceiling_id = $1 AND status IN ('PENDING', 'SUBMITTED');

-- name: ListPayersWithStalePending :many
-- Returns distinct payer_user_ids whose oldest PENDING payment is older
-- than $1. Used by the auto-settle sweeper.
SELECT payer_user_id, MIN(submitted_at) AS first_pending_at
FROM payment_tokens
WHERE status = 'PENDING'
GROUP BY payer_user_id
HAVING MIN(submitted_at) < $1;

-- name: UpdatePaymentStatus :one
UPDATE payment_tokens
SET status = $2,
    rejection_reason = $3,
    settled_amount_kobo = $4,
    settlement_batch_id = $5,
    submitted_at = COALESCE(submitted_at, $6),
    settled_at = $7,
    updated_at = now()
WHERE id = $1
RETURNING *;

-- ----------------------------------------------------------------------
-- Admin list + count projections for payment_tokens.
--
-- The backoffice supports filtering by any combination of {status,
-- payer, payee, settlement_batch_id}. Following the codebase's "no
-- runtime-built SQL" rule, the eight combinations are spelled out as
-- named queries with matching count twins; the service layer dispatches
-- on which filter fields are non-empty.
-- ----------------------------------------------------------------------

-- ListPaymentTokensForAdmin is the unfiltered admin transactions feed:
-- UNION-ALL of `payment_tokens` (offline ceiling-backed flow) and
-- `transfers` (online P2P flow), normalised to a single row shape
-- tagged with `kind` so the UI can distinguish the source.
--
-- The filtered variants below stay payment_tokens-only — their
-- predicates (payment_status enum, batch_id, sequence_number) don't
-- have analogues on the transfers side.
--
-- name: ListPaymentTokensForAdmin :many
SELECT id, payer_user_id, payee_user_id, amount_kobo, settled_amount_kobo,
       status, sequence_number, ceiling_id, settlement_batch_id,
       rejection_reason, created_at, submitted_at, settled_at, kind
FROM (
    SELECT id, payer_user_id, payee_user_id, amount_kobo, settled_amount_kobo,
           status::text AS status, sequence_number, ceiling_id, settlement_batch_id,
           rejection_reason, created_at, submitted_at, settled_at,
           'payment_token'::text AS kind
    FROM payment_tokens
    UNION ALL
    SELECT id,
           sender_user_id   AS payer_user_id,
           receiver_user_id AS payee_user_id,
           amount_kobo,
           (CASE WHEN status = 'SETTLED' THEN amount_kobo ELSE 0 END)::BIGINT AS settled_amount_kobo,
           status,
           0::BIGINT        AS sequence_number,
           ''::text         AS ceiling_id,
           NULL::text       AS settlement_batch_id,
           failure_reason   AS rejection_reason,
           created_at,
           NULL::timestamptz AS submitted_at,
           settled_at,
           'transfer'::text AS kind
    FROM transfers
) movements
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;

-- name: ListPaymentTokensForAdminByStatus :many
SELECT id, payer_user_id, payee_user_id, amount_kobo, settled_amount_kobo,
       status::text AS status, sequence_number, ceiling_id, settlement_batch_id,
       rejection_reason, created_at, submitted_at, settled_at,
       'payment_token'::text AS kind
FROM payment_tokens
WHERE status::text = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListPaymentTokensForAdminByPayer :many
SELECT id, payer_user_id, payee_user_id, amount_kobo, settled_amount_kobo,
       status::text AS status, sequence_number, ceiling_id, settlement_batch_id,
       rejection_reason, created_at, submitted_at, settled_at,
       'payment_token'::text AS kind
FROM payment_tokens
WHERE payer_user_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListPaymentTokensForAdminByPayee :many
SELECT id, payer_user_id, payee_user_id, amount_kobo, settled_amount_kobo,
       status::text AS status, sequence_number, ceiling_id, settlement_batch_id,
       rejection_reason, created_at, submitted_at, settled_at,
       'payment_token'::text AS kind
FROM payment_tokens
WHERE payee_user_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListPaymentTokensForAdminByBatch :many
SELECT id, payer_user_id, payee_user_id, amount_kobo, settled_amount_kobo,
       status::text AS status, sequence_number, ceiling_id, settlement_batch_id,
       rejection_reason, created_at, submitted_at, settled_at,
       'payment_token'::text AS kind
FROM payment_tokens
WHERE settlement_batch_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListPaymentTokensForAdminByStatusAndPayer :many
SELECT id, payer_user_id, payee_user_id, amount_kobo, settled_amount_kobo,
       status::text AS status, sequence_number, ceiling_id, settlement_batch_id,
       rejection_reason, created_at, submitted_at, settled_at,
       'payment_token'::text AS kind
FROM payment_tokens
WHERE status::text = $1 AND payer_user_id = $2
ORDER BY created_at DESC
LIMIT $3 OFFSET $4;

-- name: ListPaymentTokensForAdminByStatusAndPayee :many
SELECT id, payer_user_id, payee_user_id, amount_kobo, settled_amount_kobo,
       status::text AS status, sequence_number, ceiling_id, settlement_batch_id,
       rejection_reason, created_at, submitted_at, settled_at,
       'payment_token'::text AS kind
FROM payment_tokens
WHERE status::text = $1 AND payee_user_id = $2
ORDER BY created_at DESC
LIMIT $3 OFFSET $4;

-- name: ListPaymentTokensForAdminByPayerAndPayee :many
SELECT id, payer_user_id, payee_user_id, amount_kobo, settled_amount_kobo,
       status::text AS status, sequence_number, ceiling_id, settlement_batch_id,
       rejection_reason, created_at, submitted_at, settled_at,
       'payment_token'::text AS kind
FROM payment_tokens
WHERE payer_user_id = $1 AND payee_user_id = $2
ORDER BY created_at DESC
LIMIT $3 OFFSET $4;

-- name: ListPaymentTokensForAdminByStatusAndPayerAndPayee :many
SELECT id, payer_user_id, payee_user_id, amount_kobo, settled_amount_kobo,
       status::text AS status, sequence_number, ceiling_id, settlement_batch_id,
       rejection_reason, created_at, submitted_at, settled_at,
       'payment_token'::text AS kind
FROM payment_tokens
WHERE status::text = $1 AND payer_user_id = $2 AND payee_user_id = $3
ORDER BY created_at DESC
LIMIT $4 OFFSET $5;

-- Count twins. Each variant shares its WHERE clause with the matching
-- List query so the page total is exactly the row count the listing
-- would produce.

-- CountPaymentTokensForAdmin counts both streams of the unified feed
-- (payment_tokens + transfers) so the unfiltered page total matches
-- the UNION ALL in ListPaymentTokensForAdmin.
--
-- name: CountPaymentTokensForAdmin :one
SELECT (
    (SELECT COUNT(*) FROM payment_tokens)
  + (SELECT COUNT(*) FROM transfers)
)::BIGINT AS total;

-- name: CountPaymentTokensForAdminByStatus :one
SELECT COUNT(*)::BIGINT AS total FROM payment_tokens WHERE status::text = $1;

-- name: CountPaymentTokensForAdminByPayer :one
SELECT COUNT(*)::BIGINT AS total FROM payment_tokens WHERE payer_user_id = $1;

-- name: CountPaymentTokensForAdminByPayee :one
SELECT COUNT(*)::BIGINT AS total FROM payment_tokens WHERE payee_user_id = $1;

-- name: CountPaymentTokensForAdminByBatch :one
SELECT COUNT(*)::BIGINT AS total FROM payment_tokens WHERE settlement_batch_id = $1;

-- name: CountPaymentTokensForAdminByStatusAndPayer :one
SELECT COUNT(*)::BIGINT AS total FROM payment_tokens
WHERE status::text = $1 AND payer_user_id = $2;

-- name: CountPaymentTokensForAdminByStatusAndPayee :one
SELECT COUNT(*)::BIGINT AS total FROM payment_tokens
WHERE status::text = $1 AND payee_user_id = $2;

-- name: CountPaymentTokensForAdminByPayerAndPayee :one
SELECT COUNT(*)::BIGINT AS total FROM payment_tokens
WHERE payer_user_id = $1 AND payee_user_id = $2;

-- name: CountPaymentTokensForAdminByStatusAndPayerAndPayee :one
SELECT COUNT(*)::BIGINT AS total FROM payment_tokens
WHERE status::text = $1 AND payer_user_id = $2 AND payee_user_id = $3;

-- GetPaymentTokenForAdmin is the single-row accessor for the
-- transaction-detail endpoint. Column set matches the List variants
-- above so the UI renders with one adapter.
--
-- name: GetPaymentTokenForAdmin :one
SELECT id, payer_user_id, payee_user_id, amount_kobo, settled_amount_kobo,
       status::text AS status, sequence_number, ceiling_id, settlement_batch_id,
       rejection_reason, created_at, submitted_at, settled_at,
       'payment_token'::text AS kind
FROM payment_tokens
WHERE id = $1;

-- GetTransferForAdmin is the transfer-detail accessor. Returns the
-- same shape as GetPaymentTokenForAdmin so the admin service can
-- look up either kind by id and hand the dashboard a uniform row.
--
-- name: GetTransferForAdmin :one
SELECT id,
       sender_user_id   AS payer_user_id,
       receiver_user_id AS payee_user_id,
       amount_kobo,
       (CASE WHEN status = 'SETTLED' THEN amount_kobo ELSE 0 END)::BIGINT AS settled_amount_kobo,
       status,
       0::BIGINT        AS sequence_number,
       ''::text         AS ceiling_id,
       NULL::text       AS settlement_batch_id,
       failure_reason   AS rejection_reason,
       created_at,
       NULL::timestamptz AS submitted_at,
       settled_at,
       'transfer'::text AS kind
FROM transfers
WHERE id = $1;

-- ----------------------------------------------------------------------
-- Dashboard aggregates
-- ----------------------------------------------------------------------

-- AdminOverviewStats is the dashboard landing query — one round trip
-- for every tile on the landing page. Column ordering is significant:
-- the service maps the result positionally, so additions append rather
-- than insert.
--
-- txn_count_24h / txn_volume_24h_kobo aggregate BOTH money-movement
-- streams (offline payment_tokens + online transfers). Counting only
-- one stream would under-report whenever the bulk of activity is on
-- the other, which is common early in operation.
--
-- name: AdminOverviewStats :one
SELECT
    (SELECT COUNT(*) FROM users)::BIGINT                                                     AS users_total,
    (SELECT COUNT(DISTINCT user_id) FROM devices WHERE last_seen_at > now() - interval '24 hours')::BIGINT AS users_active_24h,
    (SELECT COUNT(DISTINCT user_id) FROM devices WHERE last_seen_at > now() - interval '7 days')::BIGINT   AS users_active_7d,
    (SELECT COUNT(*) FROM devices WHERE active = TRUE)::BIGINT                                AS devices_active,
    COALESCE((SELECT SUM(balance_kobo) FROM accounts WHERE kind = 'lien_holding'), 0)::BIGINT AS lien_float_kobo,
    COALESCE((SELECT SUM(balance_kobo) FROM accounts WHERE kind = 'receiving_pending'), 0)::BIGINT AS pending_settlement_kobo,
    (
        (SELECT COUNT(*) FROM payment_tokens WHERE created_at > now() - interval '24 hours')
      + (SELECT COUNT(*) FROM transfers       WHERE created_at > now() - interval '24 hours')
    )::BIGINT AS txn_count_24h,
    (
        COALESCE((SELECT SUM(amount_kobo) FROM payment_tokens WHERE created_at > now() - interval '24 hours'), 0)
      + COALESCE((SELECT SUM(amount_kobo) FROM transfers       WHERE created_at > now() - interval '24 hours'), 0)
    )::BIGINT AS txn_volume_24h_kobo,
    (SELECT COUNT(*) FROM fraud_signals WHERE created_at > now() - interval '24 hours')::BIGINT AS fraud_signals_24h,
    (SELECT COUNT(*) FROM ceiling_tokens WHERE status = 'ACTIVE')::BIGINT                      AS ceilings_active;

-- AdminVolumeSeries returns a per-day count + volume for the last $1
-- days, summed across payment_tokens (offline) and transfers (online
-- P2P). The inner UNION ALL keeps each row source-attributable so a
-- future chart variant can split by stream without a schema change;
-- the outer aggregate matches the single-line view the dashboard
-- currently renders.
--
-- Caller validates the 1..180 range; we multiply the int-day value
-- into an interval rather than inline-formatting it.
--
-- name: AdminVolumeSeries :many
SELECT date_trunc('day', created_at)::timestamptz AS day,
       COUNT(*)::BIGINT                           AS count,
       COALESCE(SUM(amount_kobo), 0)::BIGINT      AS volume_kobo
FROM (
    SELECT amount_kobo, created_at FROM payment_tokens
    WHERE created_at > now() - ($1::int * interval '1 day')
    UNION ALL
    SELECT amount_kobo, created_at FROM transfers
    WHERE created_at > now() - ($1::int * interval '1 day')
) movements
GROUP BY 1
ORDER BY 1;

-- ----------------------------------------------------------------------
-- Settlement batch rollups
-- ----------------------------------------------------------------------

-- name: CountSettlementBatches :one
SELECT COUNT(DISTINCT settlement_batch_id)::BIGINT AS total
FROM payment_tokens
WHERE settlement_batch_id IS NOT NULL;

-- name: ListSettlementBatches :many
SELECT settlement_batch_id                                      AS id,
       COUNT(*)::BIGINT                                         AS txn_count,
       COALESCE(SUM(amount_kobo), 0)::BIGINT                    AS submitted_volume_kobo,
       COALESCE(SUM(settled_amount_kobo), 0)::BIGINT            AS settled_volume_kobo,
       MIN(submitted_at)::timestamptz                           AS first_submitted_at,
       MAX(settled_at)::timestamptz                             AS last_settled_at
FROM payment_tokens
WHERE settlement_batch_id IS NOT NULL
GROUP BY settlement_batch_id
ORDER BY MAX(COALESCE(settled_at, submitted_at, created_at)) DESC NULLS LAST
LIMIT $1 OFFSET $2;

-- name: GetSettlementBatchHeader :one
SELECT $1::text                                                 AS id,
       COUNT(*)::BIGINT                                         AS txn_count,
       COALESCE(SUM(amount_kobo), 0)::BIGINT                    AS submitted_volume_kobo,
       COALESCE(SUM(settled_amount_kobo), 0)::BIGINT            AS settled_volume_kobo,
       MIN(submitted_at)::timestamptz                           AS first_submitted_at,
       MAX(settled_at)::timestamptz                             AS last_settled_at
FROM payment_tokens
WHERE settlement_batch_id = $1;

-- name: GetSettlementBatchStatusCounts :many
SELECT status::text AS status,
       COUNT(*)::BIGINT AS count
FROM payment_tokens
WHERE settlement_batch_id = $1
GROUP BY status;
