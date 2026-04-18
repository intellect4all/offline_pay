-- Fraud signals (cryptographic/offline anomalies on payment_tokens)
-- and fraud scores (scoring decisions on online transfers). The two
-- streams are distinct domains and deliberately unioned only at the
-- admin-reporting layer.

-- name: InsertFraudSignal :one
INSERT INTO fraud_signals (
    id, user_id, signal_type, ceiling_token_id, transaction_id,
    details, severity, weight
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: ListFraudSignalsByUser :many
SELECT * FROM fraud_signals
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT $2;

-- name: CountFraudSignalsByUser :one
SELECT COUNT(*)::BIGINT AS count FROM fraud_signals WHERE user_id = $1;

-- name: ListFraudSignalsForUser :many
SELECT * FROM fraud_signals
WHERE user_id = $1
ORDER BY created_at DESC;

-- InsertFraudScore records a BLOCK or FLAG decision for one transfer.
-- ALLOW outcomes are trace-only and never written to this table so it
-- stays small and queryable.
--
-- name: InsertFraudScore :exec
INSERT INTO fraud_scores
    (id, transfer_id, sender_id, decision, rule, reason, rule_hits, amount_kobo)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8);

-- ListFraudSignalsForAdmin powers the backoffice user-detail view.
-- Caller caps via $2; typical page is 20 newest signals.
--
-- name: ListFraudSignalsForAdmin :many
SELECT id,
       signal_type::text AS signal,
       severity,
       weight,
       created_at
FROM fraud_signals
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT $2;

-- ListFraudSignalsGlobal powers the fraud dashboard. Widens the
-- per-user projection with user_id, details, and the optional ceiling
-- and transaction refs so the operator can click through to context
-- from a single page.
--
-- name: ListFraudSignalsGlobal :many
SELECT id,
       user_id,
       signal_type::text AS signal,
       severity,
       weight,
       details,
       ceiling_token_id,
       transaction_id,
       created_at
FROM fraud_signals
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;

-- name: CountFraudSignalsGlobal :one
SELECT COUNT(*)::BIGINT AS count FROM fraud_signals;
