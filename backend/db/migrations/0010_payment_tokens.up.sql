-- Payment tokens are payer-signed claims attached to a ceiling.
--
-- `signed_at` is the device-clock timestamp at which the payer's app
-- produced and signed the token. It is part of the canonical signed
-- payload (audit-only, not used for ordering — sequence_number is the
-- ordering key).
--
-- Later migrations extend this table for PaymentRequest binding (0024)
-- and submitter attribution (0025). The core contract below is the
-- original offline-payment protocol shape.

CREATE TYPE payment_status AS ENUM (
    'QUEUED',
    'SUBMITTED',
    'PENDING',
    'SETTLED',
    'PARTIALLY_SETTLED',
    'REJECTED',
    'EXPIRED'
);

CREATE TABLE payment_tokens (
    id                       TEXT PRIMARY KEY,
    ceiling_id               TEXT NOT NULL REFERENCES ceiling_tokens (id),
    payer_user_id            TEXT NOT NULL REFERENCES users (id),
    payee_user_id            TEXT NOT NULL REFERENCES users (id),
    amount_kobo              BIGINT NOT NULL CHECK (amount_kobo > 0),
    sequence_number          BIGINT NOT NULL CHECK (sequence_number > 0),
    remaining_ceiling_kobo   BIGINT NOT NULL CHECK (remaining_ceiling_kobo >= 0),
    settled_amount_kobo      BIGINT NOT NULL DEFAULT 0 CHECK (settled_amount_kobo >= 0),
    signed_at                TIMESTAMPTZ NOT NULL,
    payer_sig                BYTEA NOT NULL,
    status                   payment_status NOT NULL DEFAULT 'QUEUED',
    rejection_reason         TEXT,
    settlement_batch_id      TEXT,
    submitted_at             TIMESTAMPTZ,
    settled_at               TIMESTAMPTZ,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (payer_user_id, sequence_number),
    CHECK (payer_user_id <> payee_user_id)
);

CREATE INDEX idx_payment_ceiling ON payment_tokens (ceiling_id, sequence_number);
CREATE INDEX idx_payment_payee_status ON payment_tokens (payee_user_id, status);
CREATE INDEX idx_payment_status ON payment_tokens (status);
