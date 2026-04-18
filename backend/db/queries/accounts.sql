-- Account CRUD + balance mutators. The ledger layer owns all writes to
-- balance_kobo via the Increment/Decrement helpers so the account row
-- and its ledger entries always move together inside one tx.

-- name: CreateAccount :one
INSERT INTO accounts (id, user_id, kind, balance_kobo)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- EnsureSystemSuspenseAccount is an idempotent boot-time safety net for
-- the singleton suspense account + its owning system user. The initial
-- schema seeds both rows, so on a freshly migrated DB this is a no-op;
-- the upsert exists to keep Phase 4a ledger posts (which DEBIT
-- system-suspense) working against DBs restored from partial backups or
-- ad-hoc dev wipes.
--
-- The system user is invisible to any human-facing surface — it never
-- logs in, and the SYSTEM kyc_tier + non-numeric account_number keep it
-- out of the signup/transfer paths.
--
-- name: EnsureSystemSuspenseAccount :exec
WITH ensure_user AS (
    INSERT INTO users (
        id, phone, account_number, bvn, kyc_tier,
        device_attestation_id, realm_key_version, created_at,
        first_name, last_name, email, password_hash, email_verified
    )
    VALUES (
        'system-settlement', 'system-settlement', '0000000000', NULL, 'SYSTEM',
        NULL, 0, now(),
        'System', 'Settlement', 'system-settlement@internal.invalid', '', false
    )
    ON CONFLICT (id) DO NOTHING
    RETURNING id
)
INSERT INTO accounts (id, user_id, kind, balance_kobo, created_at, updated_at)
VALUES ('system-suspense', 'system-settlement', 'suspense', 0, now(), now())
ON CONFLICT (id) DO NOTHING;

-- name: GetAccount :one
SELECT * FROM accounts WHERE id = $1;

-- name: GetAccountByUserAndKind :one
SELECT * FROM accounts WHERE user_id = $1 AND kind = $2;

-- name: ListAccountsByUser :many
SELECT * FROM accounts WHERE user_id = $1 ORDER BY kind;

-- name: IncrementAccountBalance :one
UPDATE accounts
SET balance_kobo = balance_kobo + $2, updated_at = now()
WHERE id = $1
RETURNING *;

-- name: DecrementAccountBalance :one
UPDATE accounts
SET balance_kobo = balance_kobo - $2, updated_at = now()
WHERE id = $1 AND balance_kobo >= $2
RETURNING *;

-- ForceDecrementAccountBalance is the unguarded decrement path. Only
-- valid for account kinds exempt from the non-negative check — in
-- practice, the suspense account while it briefly holds the merchant
-- leg of a two-phase settlement.
--
-- name: ForceDecrementAccountBalance :one
UPDATE accounts
SET balance_kobo = balance_kobo - $2, updated_at = now()
WHERE id = $1
RETURNING *;

-- LockMainAccountForUser takes a row-level lock on the user's main
-- account so the transfer processor can debit and credit inside one tx.
-- FOR UPDATE is required: concurrent transfer ledger writes must
-- serialise through this lock to preserve balance invariants.
--
-- name: LockMainAccountForUser :one
SELECT id, user_id FROM accounts
WHERE user_id = $1 AND kind = 'main'
FOR UPDATE;

-- GetUserBalancesForAdmin is the backoffice user-detail single-row
-- lookup. Joins the main + lien-holding balances so one round trip
-- renders the whole panel. Returns one row even when the user has no
-- accounts provisioned yet — COALESCE holds the balances at 0.
--
-- The "lien" balance is the live offline-wallet float: funds committed
-- to an active ceiling and spendable offline via signed payment tokens.
--
-- name: GetUserBalancesForAdmin :one
SELECT u.id,
       u.phone,
       u.kyc_tier,
       u.realm_key_version,
       u.created_at,
       COALESCE(am.balance_kobo, 0)::BIGINT AS main_balance_kobo,
       COALESCE(al.balance_kobo, 0)::BIGINT AS lien_balance_kobo,
       (SELECT MAX(last_seen_at) FROM devices WHERE user_id = u.id)::timestamptz AS last_seen_at
FROM users u
LEFT JOIN accounts am ON am.user_id = u.id AND am.kind = 'main'
LEFT JOIN accounts al ON al.user_id = u.id AND al.kind = 'lien_holding'
WHERE u.id = $1;

-- ListAccountsForAdmin returns every account row for one user, with
-- `kind` cast to text for the admin JSON payload (the frontend treats
-- it as an opaque string).
--
-- name: ListAccountsForAdmin :many
SELECT id,
       kind::text AS kind,
       balance_kobo
FROM accounts
WHERE user_id = $1
ORDER BY kind;
