-- Ed25519 signing keys belonging to end users. The private key lives on
-- the device (hardware-backed keystore); only the public half is stored
-- here.
--
-- The key is bound to the user (not the device row) because ceiling
-- tokens outlive device re-provisioning events. `device_id` is recorded
-- when known so audits can attribute a key to a specific provisioning
-- event, but it stays nullable.
--
-- Rotation: a new active row is inserted, the previous active row is
-- updated (active = FALSE, rotated_at = now()). Only one row may be
-- active per user at a time. Historic ceilings continue to verify
-- because they snapshot the pubkey bytes into ceiling_tokens.payer_pubkey
-- at issuance.

CREATE TABLE signing_keys (
    id         TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    device_id  TEXT,
    public_key BYTEA NOT NULL,
    active     BOOLEAN NOT NULL DEFAULT TRUE,
    rotated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_signing_keys_one_active_per_user
    ON signing_keys (user_id)
    WHERE active = TRUE;

CREATE INDEX idx_signing_keys_user ON signing_keys (user_id, created_at DESC);
