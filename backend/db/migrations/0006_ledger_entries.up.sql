-- Double-entry ledger. Each txn_id groups a set of entries that MUST
-- balance: SUM(direction='DEBIT') = SUM(direction='CREDIT'). Enforced
-- by a deferred constraint trigger so a multi-statement transaction can
-- insert several entries before the check runs at COMMIT.
--
-- The FK from txn_id to transactions.id is installed in 0018 once the
-- transactions table exists; until then, txn_id is an untyped key that
-- the application layer owns.

CREATE TYPE ledger_direction AS ENUM ('DEBIT', 'CREDIT');

CREATE TABLE ledger_entries (
    id          TEXT PRIMARY KEY,
    txn_id      TEXT NOT NULL,
    account_id  TEXT NOT NULL REFERENCES accounts (id),
    direction   ledger_direction NOT NULL,
    amount_kobo BIGINT NOT NULL CHECK (amount_kobo > 0),
    memo        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_ledger_txn ON ledger_entries (txn_id);
CREATE INDEX idx_ledger_account ON ledger_entries (account_id);

CREATE OR REPLACE FUNCTION check_ledger_txn_balanced()
RETURNS TRIGGER AS $$
DECLARE
    debit_sum  BIGINT;
    credit_sum BIGINT;
    target_txn TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_txn := OLD.txn_id;
    ELSE
        target_txn := NEW.txn_id;
    END IF;

    SELECT
        COALESCE(SUM(CASE WHEN direction = 'DEBIT'  THEN amount_kobo ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN direction = 'CREDIT' THEN amount_kobo ELSE 0 END), 0)
    INTO debit_sum, credit_sum
    FROM ledger_entries
    WHERE txn_id = target_txn;

    IF debit_sum <> credit_sum THEN
        RAISE EXCEPTION 'ledger txn % unbalanced: debits=% credits=%',
            target_txn, debit_sum, credit_sum
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_ledger_balanced
    AFTER INSERT OR UPDATE OR DELETE ON ledger_entries
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION check_ledger_txn_balanced();
