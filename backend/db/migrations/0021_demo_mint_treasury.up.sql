-- Demo-funding feature (part 2 of 2). Seeds the demo-mint treasury with
-- ₦5,000,000,000 (500_000_000_000 kobo) so the /demo/fund flow can
-- transfer money to users while preserving the double-entry invariant
-- enforced by check_ledger_txn_balanced.
--
-- Three rows are created:
--   1. users.system-mint              — singleton owner, kyc_tier=SYSTEM.
--   2. accounts.system-mint-treasury  — kind=main, pre-funded with 5B.
--   3. accounts.system-mint-source    — kind=suspense, counterweight (-5B).
--
-- The genesis ledger entry (DEBIT source, CREDIT treasury) lets
-- SUM(ledger) == account.balance hold for both accounts while the
-- balanced-transaction trigger is satisfied. The suspense kind is the
-- only one exempt from accounts_balance_nonneg, so -5B is legal on the
-- source side.
--
-- A single system-owned transactions row anchors the genesis ledger
-- entries, satisfying ledger_entries.txn_id → transactions.id. The
-- anchor row does not surface in user-facing history (system-mint is
-- not a real user). DEMO_MINT remains the runtime kind for per-user
-- top-ups.

INSERT INTO users (
    id, phone, account_number, bvn, kyc_tier, device_attestation_id,
    realm_key_version, first_name, last_name, email, password_hash, created_at
) VALUES (
    'system-mint', 'system-mint', '0000000001', NULL, 'SYSTEM', NULL,
    0, 'System', 'Mint', 'system-mint@offlinepay.local', '', now()
);

INSERT INTO accounts (id, user_id, kind, balance_kobo)
VALUES ('system-mint-treasury', 'system-mint', 'main', 500000000000);

INSERT INTO accounts (id, user_id, kind, balance_kobo)
VALUES ('system-mint-source', 'system-mint', 'suspense', -500000000000);

DO $$
DECLARE
    genesis_txn TEXT := '01HGENES1S0000000000000MINT';
BEGIN
    -- Anchor transactions row for the genesis ledger FK. Both ledger legs
    -- reference this single txn_id — same pattern the runtime uses when
    -- posting balanced ledger transactions.
    INSERT INTO transactions (
        id, user_id, kind, status, direction, amount_kobo, group_id,
        memo, created_at, updated_at
    ) VALUES (
        genesis_txn, 'system-mint', 'DEMO_MINT', 'COMPLETED', 'CREDIT',
        500000000000, genesis_txn,
        'genesis: demo-mint treasury seed', now(), now()
    );

    INSERT INTO ledger_entries (id, txn_id, account_id, direction, amount_kobo, memo)
    VALUES
      (genesis_txn || '-D', genesis_txn, 'system-mint-source',
       'DEBIT',  500000000000, 'genesis: demo-mint treasury seed'),
      (genesis_txn || '-C', genesis_txn, 'system-mint-treasury',
       'CREDIT', 500000000000, 'genesis: demo-mint treasury seed');
END $$;
