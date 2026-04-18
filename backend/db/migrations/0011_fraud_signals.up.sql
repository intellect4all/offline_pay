-- Cryptographic / offline-ceiling anomaly signals tied to payment_tokens.
-- Online intra-bank transfer scoring lives in fraud_scores (separate
-- domain, separate table).

CREATE TYPE fraud_signal_type AS ENUM (
    'DOUBLE_SPEND',
    'CEILING_EXHAUSTION',
    'GEOGRAPHIC_ANOMALY',
    'SEQUENCE_ANOMALY',
    'DEVICE_CHANGE',
    'VELOCITY_BREACH',
    'SIGNATURE_INVALID'
);

CREATE TABLE fraud_signals (
    id                TEXT PRIMARY KEY,
    user_id           TEXT NOT NULL REFERENCES users (id),
    signal_type       fraud_signal_type NOT NULL,
    ceiling_token_id  TEXT REFERENCES ceiling_tokens (id),
    transaction_id    TEXT REFERENCES payment_tokens (id),
    details           TEXT NOT NULL DEFAULT '',
    severity          TEXT NOT NULL DEFAULT 'LOW',
    weight            DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_fraud_user ON fraud_signals (user_id, created_at DESC);
