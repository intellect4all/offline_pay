ALTER TABLE ledger_entries DROP CONSTRAINT IF EXISTS fk_ledger_txn;
DROP TABLE IF EXISTS transactions;
DROP TYPE IF EXISTS transaction_lifecycle_status;
DROP TYPE IF EXISTS transaction_kind;
