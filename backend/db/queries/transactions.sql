-- transactions is the business-event log that anchors the ledger. Any
-- service mutating the ledger inserts a transactions row in the same
-- tx as its ledger posts; ledger_entries.txn_id FKs transactions.id,
-- so the row MUST land before COMMIT for the FK to hold.

-- name: RecordTransaction :exec
INSERT INTO transactions (
    id, group_id, user_id, counterparty_user_id,
    kind, status, direction,
    amount_kobo, settled_amount_kobo,
    memo,
    payment_token_id, transfer_id, ceiling_id,
    failure_reason
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14);

-- UpdateTransactionStatus transitions status and optionally carries
-- a settled amount + failure reason. Callers pass NULLs for fields
-- that should not change; updated_at always bumps so observers can
-- detect the transition.
--
-- name: UpdateTransactionStatus :exec
UPDATE transactions
SET status              = $2,
    settled_amount_kobo = COALESCE($3, settled_amount_kobo),
    failure_reason      = COALESCE($4, failure_reason),
    updated_at          = now()
WHERE id = $1;

-- name: GetTransaction :one
SELECT * FROM transactions WHERE id = $1;

-- GetTransactionAnchorForPayment returns the DEBIT-side (payer-side)
-- row's id + group_id for a payment token. Phase 4b reuses this id
-- as the ledger txn_id so the FK holds and the balance trigger sees
-- one grouped posting, then flips both paired rows' status via
-- ListTransactionsByGroup.
--
-- name: GetTransactionAnchorForPayment :one
SELECT id, group_id FROM transactions
WHERE payment_token_id = $1 AND direction = 'DEBIT'
LIMIT 1;

-- GetTransactionAnchorForTransfer is the transfer-processor analogue
-- for online P2P transfers; same reuse-the-DEBIT-id contract.
--
-- name: GetTransactionAnchorForTransfer :one
SELECT id, group_id FROM transactions
WHERE transfer_id = $1 AND direction = 'DEBIT'
LIMIT 1;

-- ListTransactionsByGroup returns both rows of a paired two-party
-- event. Settlement and transfer-finalise paths use this to flip
-- both sides' status atomically inside the finalising tx.
--
-- name: ListTransactionsByGroup :many
SELECT * FROM transactions
WHERE group_id = $1
ORDER BY direction;

-- ListTransactionsForUser is the user-facing history feed. Newest
-- first, with a stable id tiebreaker so the page boundary doesn't
-- shift between reads at the same timestamp.
--
-- name: ListTransactionsForUser :many
SELECT * FROM transactions
WHERE user_id = $1
ORDER BY created_at DESC, id DESC
LIMIT $2 OFFSET $3;

-- name: CountTransactionsForUser :one
SELECT COUNT(*)::BIGINT AS total FROM transactions WHERE user_id = $1;
