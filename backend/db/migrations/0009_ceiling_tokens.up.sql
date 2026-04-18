-- Bank-signed token authorising offline spending up to `ceiling_kobo`.
-- `payer_pubkey` is a snapshot of the active signing_keys row at issuance
-- — kept as bytes (not a FK) so verification is stable through future
-- key rotation.
--
-- Lifecycle: ACTIVE → {EXPIRED, EXHAUSTED, REVOKED}. At most one ACTIVE
-- ceiling per payer (partial unique index below). Recovery-flow states
-- are layered on in 0022.

CREATE TYPE ceiling_status AS ENUM ('ACTIVE', 'EXPIRED', 'EXHAUSTED', 'REVOKED');

CREATE TABLE ceiling_tokens (
    id               TEXT PRIMARY KEY,
    payer_user_id    TEXT NOT NULL REFERENCES users (id),
    ceiling_kobo     BIGINT NOT NULL CHECK (ceiling_kobo > 0),
    sequence_start   BIGINT NOT NULL CHECK (sequence_start >= 0),
    issued_at        TIMESTAMPTZ NOT NULL,
    expires_at       TIMESTAMPTZ NOT NULL,
    payer_pubkey     BYTEA NOT NULL,
    bank_key_id      TEXT NOT NULL,
    bank_sig         BYTEA NOT NULL,
    status           ceiling_status NOT NULL DEFAULT 'ACTIVE',
    lien_account_id  TEXT NOT NULL REFERENCES accounts (id),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_ceiling_one_active_per_user
    ON ceiling_tokens (payer_user_id)
    WHERE status = 'ACTIVE';

CREATE INDEX idx_ceiling_payer_status ON ceiling_tokens (payer_user_id, status);
CREATE INDEX idx_ceiling_expires ON ceiling_tokens (expires_at);
