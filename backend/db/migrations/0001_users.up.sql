-- Users are the single end-user entity in this C2C system. Every user can
-- both send and receive. IDs are ULID strings stored as TEXT.
--
-- Identity columns:
--   phone          — E.164 normalised, unique. Not a credential.
--   account_number — public 10-digit handle used for transfers.
--   email          — unique (case-insensitive); used for signup verification
--                    and password reset. Carries the password credential.
--   bvn            — optional, stored in plaintext for auditing and
--                    regulator checks. Column-level encryption at rest is
--                    a pre-production checklist item (pgcrypto/pgsodium +
--                    KMS-managed key).
--
-- KYC tiers:
--   TIER_0 — phone only (pre-signup; never persisted post-signup).
--   TIER_1 — phone + name + email (default post-signup).
--   TIER_2 — NIN verified.
--   TIER_3 — BVN verified.
--   SYSTEM — singleton service accounts that own ledger plumbing (e.g.
--            the settlement suspense and demo-mint treasury owners). Never
--            issued to humans; bypasses the signup flow.

CREATE TABLE users (
    id                    TEXT PRIMARY KEY,
    phone                 TEXT NOT NULL UNIQUE,
    account_number        CHAR(10) NOT NULL UNIQUE,
    bvn                   TEXT,
    kyc_tier              TEXT NOT NULL DEFAULT 'TIER_1'
                            CHECK (kyc_tier IN ('TIER_0', 'TIER_1', 'TIER_2', 'TIER_3', 'SYSTEM')),
    device_attestation_id TEXT,
    realm_key_version     INTEGER NOT NULL DEFAULT 1,
    first_name            TEXT NOT NULL,
    last_name             TEXT NOT NULL,
    email                 TEXT NOT NULL,
    password_hash         TEXT NOT NULL,
    email_verified        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_phone ON users (phone);
CREATE INDEX idx_users_account_number ON users (account_number);
CREATE UNIQUE INDEX idx_users_email ON users (lower(email));
