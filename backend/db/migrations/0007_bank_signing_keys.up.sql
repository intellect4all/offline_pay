-- Bank-side Ed25519 keys used to sign ceiling tokens. `privkey_enc` is
-- the encrypted private key blob (or a Vault key handle when
-- CRYPTO_SIGNER=vault).

CREATE TABLE bank_signing_keys (
    key_id       TEXT PRIMARY KEY,
    pubkey       BYTEA NOT NULL,
    privkey_enc  BYTEA NOT NULL,
    active_from  TIMESTAMPTZ NOT NULL DEFAULT now(),
    retired_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_bank_keys_active
    ON bank_signing_keys (active_from)
    WHERE retired_at IS NULL;
