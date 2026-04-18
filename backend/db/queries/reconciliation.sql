-- Reconciliation run history + the read queries that back each
-- reconciler. Three reconcilers drive off this file:
--   PAYER     — per-user offline-settled payment mismatch scan.
--   MERCHANT  — per-receiver settlement-batch roll-up.
--   LEDGER    — global account-balance vs ledger-sum check.

-- name: CreateReconciliationRun :one
INSERT INTO reconciliation_runs (id, type, entity_id, status, discrepancies)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: UpdateReconciliationRun :exec
UPDATE reconciliation_runs
SET status = $2, discrepancies = $3
WHERE id = $1;

-- name: GetReconciliationRun :one
SELECT * FROM reconciliation_runs WHERE id = $1;

-- name: ListRecentReconciliationRuns :many
SELECT * FROM reconciliation_runs
WHERE type = $1
ORDER BY run_at DESC
LIMIT $2;

-- name: ListSettledTxnsForPayer :many
SELECT * FROM payment_tokens
WHERE payer_user_id = $1 AND status IN ('SETTLED', 'PARTIALLY_SETTLED')
ORDER BY sequence_number ASC;

-- name: ListSettledTxnsForReceiver :many
SELECT * FROM payment_tokens
WHERE payee_user_id = $1 AND status IN ('SETTLED', 'PARTIALLY_SETTLED')
ORDER BY created_at ASC;

-- name: AccountLedgerSum :one
SELECT
    COALESCE(SUM(CASE WHEN direction = 'DEBIT'  THEN amount_kobo ELSE 0 END), 0)::BIGINT AS debit_total,
    COALESCE(SUM(CASE WHEN direction = 'CREDIT' THEN amount_kobo ELSE 0 END), 0)::BIGINT AS credit_total
FROM ledger_entries
WHERE account_id = $1;

-- name: ListAllAccounts :many
SELECT * FROM accounts ORDER BY id ASC;

-- name: SettledTotalForCeiling :one
SELECT COALESCE(SUM(settled_amount_kobo), 0)::BIGINT AS total
FROM payment_tokens
WHERE ceiling_id = $1 AND status IN ('SETTLED', 'PARTIALLY_SETTLED');

-- name: ListAllCeilings :many
SELECT * FROM ceiling_tokens ORDER BY id ASC;

-- name: ListPaymentsByBatch :many
SELECT * FROM payment_tokens
WHERE settlement_batch_id = $1
ORDER BY sequence_number ASC;
