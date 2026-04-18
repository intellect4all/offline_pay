-- Every user has accounts in up to four lifecycle kinds; the system
-- also owns the shared `suspense` account used between the merchant-claim
-- and final-settlement legs of two-phase settlement.
--
-- Why separate kinds (and not one main + status flags): each kind
-- represents a distinct legal claim on the money — a lien is the user's
-- funds but unavailable to spend; receiving_pending may still be
-- reversed; etc. Modelling them as separate accounts keeps the
-- double-entry invariant (account.balance = SUM(its ledger entries))
-- clean and lets check_ledger_txn_balanced enforce conservation across
-- the whole transaction without per-row state columns. The API/UI layer
-- consolidates kinds into one user-facing wallet view.
--
-- The non-negative balance check is gated by kind: the suspense account
-- legitimately runs negative between Phase 4a (merchant credited) and
-- Phase 4b (payer debited).

CREATE TYPE account_kind AS ENUM (
    'main',
    'lien_holding',
    'receiving_pending',
    'suspense'
);

CREATE TABLE accounts (
    id           TEXT PRIMARY KEY,
    user_id      TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kind         account_kind NOT NULL,
    balance_kobo BIGINT NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, kind),
    CONSTRAINT accounts_balance_nonneg CHECK (kind = 'suspense' OR balance_kobo >= 0)
);

CREATE INDEX idx_accounts_user ON accounts (user_id);

-- Singleton system user that owns the shared suspense account. Uses a
-- sentinel phone/email/account_number that cannot be produced by the
-- signup flow; kyc_tier='SYSTEM' keeps it out of human-facing surfaces.
INSERT INTO users (
    id, phone, account_number, bvn, kyc_tier, device_attestation_id,
    realm_key_version, first_name, last_name, email, password_hash, created_at
) VALUES (
    'system-settlement', 'system-settlement', '0000000000', NULL, 'SYSTEM',
    NULL, 0, 'System', 'Settlement', 'system-settlement@internal.invalid', '', now()
);

INSERT INTO accounts (id, user_id, kind, balance_kobo)
VALUES ('system-suspense', 'system-settlement', 'suspense', 0);
