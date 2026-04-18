-- Business-event log + user-facing transaction history. Every
-- ledger-impacting service operation writes one row PER affected user
-- inside the same Repo.Tx as its ledger posts and balance updates.
--
-- Two-party events (offline payment, intra-bank transfer) write TWO
-- rows — one per user, paired by group_id, with `direction` from each
-- user's POV. The DEBIT side's `id` is reused as `ledger_entries.txn_id`
-- so the fk_ledger_txn FK lands; the CREDIT-side row gets a fresh
-- ULID and shares group_id with its partner.
--
-- Single-party events (OFFLINE_FUND, OFFLINE_DRAIN, OFFLINE_EXPIRY_RELEASE)
-- write ONE row whose group_id equals its id.
--
-- The enum starts with the core set of kinds. Later migrations add
-- DEMO_MINT (0020, for the demo-funding feature) and
-- OFFLINE_RECOVERY_RELEASE (0022, for the ceiling-recovery feature).

CREATE TYPE transaction_kind AS ENUM (
    'OFFLINE_FUND',
    'OFFLINE_DRAIN',
    'OFFLINE_EXPIRY_RELEASE',
    'OFFLINE_PAYMENT_SENT',
    'OFFLINE_PAYMENT_RECEIVED',
    'TRANSFER_SENT',
    'TRANSFER_RECEIVED'
);

CREATE TYPE transaction_lifecycle_status AS ENUM (
    'PENDING',
    'COMPLETED',
    'FAILED',
    'REVERSED'
);

CREATE TABLE transactions (
    id                    TEXT PRIMARY KEY,
    user_id               TEXT NOT NULL REFERENCES users (id),
    counterparty_user_id  TEXT REFERENCES users (id),
    kind                  transaction_kind NOT NULL,
    status                transaction_lifecycle_status NOT NULL,
    direction             ledger_direction NOT NULL,
    amount_kobo           BIGINT NOT NULL CHECK (amount_kobo > 0),
    settled_amount_kobo   BIGINT,
    memo                  TEXT,
    payment_token_id      TEXT REFERENCES payment_tokens (id),
    transfer_id           TEXT REFERENCES transfers (id),
    ceiling_id            TEXT REFERENCES ceiling_tokens (id),
    group_id              TEXT NOT NULL,
    failure_reason        TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_transactions_user_created ON transactions (user_id, created_at DESC);
CREATE INDEX idx_transactions_group ON transactions (group_id);
CREATE INDEX idx_transactions_status ON transactions (status);

-- Now that transactions.id exists, bind ledger_entries.txn_id to it.
ALTER TABLE ledger_entries
    ADD CONSTRAINT fk_ledger_txn FOREIGN KEY (txn_id) REFERENCES transactions (id);
