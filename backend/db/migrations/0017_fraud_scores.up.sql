-- Online intra-bank-transfer fraud scoring surface. Separate from
-- fraud_signals (which is the cryptographic / offline anomaly stream).
--
-- One row per scored transfer at FLAG or BLOCK level; ALLOW outcomes
-- are trace-only to keep the table small. BLOCK rows have an empty
-- transfer_id (no transfer row was created); FLAG rows point at the
-- accepted transfer for backoffice follow-up.

CREATE TABLE fraud_scores (
    id           TEXT PRIMARY KEY,
    transfer_id  TEXT NOT NULL DEFAULT '',
    sender_id    TEXT NOT NULL,
    decision     TEXT NOT NULL CHECK (decision IN ('ALLOW','FLAG','BLOCK')),
    rule         TEXT,
    reason       TEXT,
    rule_hits    JSONB NOT NULL DEFAULT '[]',
    amount_kobo  BIGINT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_fraud_scores_sender_created ON fraud_scores (sender_id, created_at DESC);
CREATE INDEX idx_fraud_scores_decision ON fraud_scores (decision);
