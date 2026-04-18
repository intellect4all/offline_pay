-- Online intra-bank user-to-user transfers, with transactional outbox
-- and processed-event idempotency. Transfers are accepted synchronously,
-- written to the outbox in the same tx, then picked up by the dispatcher
-- and mutated by the processor.
--
-- `flagged` is set true when a fraud rule fires at FLAG severity; BLOCK
-- decisions reject before any transfer row is created. fraud_scores
-- (next migration) holds the per-rule audit detail.

CREATE TABLE transfers (
    id                      TEXT PRIMARY KEY,
    sender_user_id          TEXT NOT NULL REFERENCES users (id),
    receiver_user_id        TEXT NOT NULL REFERENCES users (id),
    receiver_account_number CHAR(10) NOT NULL,
    amount_kobo             BIGINT NOT NULL CHECK (amount_kobo > 0),
    status                  TEXT NOT NULL CHECK (status IN ('ACCEPTED','PROCESSING','SETTLED','FAILED')),
    reference               TEXT NOT NULL,
    failure_reason          TEXT,
    flagged                 BOOLEAN NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    settled_at              TIMESTAMPTZ,
    UNIQUE (sender_user_id, reference)
);

CREATE INDEX idx_transfers_sender_created_at  ON transfers (sender_user_id, created_at DESC);
CREATE INDEX idx_transfers_receiver_created_at ON transfers (receiver_user_id, created_at DESC);
CREATE INDEX idx_transfers_status ON transfers (status);
CREATE INDEX idx_transfers_flagged ON transfers (flagged) WHERE flagged = TRUE;

CREATE TABLE outbox (
    id              TEXT PRIMARY KEY,
    aggregate       TEXT NOT NULL,
    aggregate_id    TEXT NOT NULL,
    payload         JSONB NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    dispatched_at   TIMESTAMPTZ,
    attempts        INTEGER NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_outbox_pending ON outbox (next_attempt_at) WHERE dispatched_at IS NULL;

CREATE TABLE processed_events (
    outbox_id    TEXT PRIMARY KEY,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    status       TEXT NOT NULL
);
