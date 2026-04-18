-- Double-entry ledger primitives. Every posting is a pair (DEBIT +
-- CREDIT) sharing one txn_id; the deferred constraint trigger on
-- ledger_entries enforces balance at COMMIT. These queries are the
-- mechanical insert/read path — ledger-balance invariants live in the
-- trigger and the Repo.Tx boundary.

-- name: InsertLedgerEntry :one
INSERT INTO ledger_entries (id, txn_id, account_id, direction, amount_kobo, memo)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: ListLedgerEntriesByTxn :many
SELECT * FROM ledger_entries WHERE txn_id = $1 ORDER BY created_at ASC;

-- name: ListLedgerEntriesByAccount :many
SELECT * FROM ledger_entries
WHERE account_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: SumAccountDebits :one
SELECT COALESCE(SUM(amount_kobo), 0)::BIGINT AS total
FROM ledger_entries WHERE account_id = $1 AND direction = 'DEBIT';

-- name: SumAccountCredits :one
SELECT COALESCE(SUM(amount_kobo), 0)::BIGINT AS total
FROM ledger_entries WHERE account_id = $1 AND direction = 'CREDIT';
