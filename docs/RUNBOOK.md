# Operator Runbook

Audience: on-call / SRE / support engineers. Assumes familiarity with Postgres and HTTP APIs.

## 1. First-time setup

```bash
git clone <repo> offline_pay && cd offline_pay
docker compose up -d                 # Postgres 16, Redis 7, NATS JetStream,
                                     # BFF, adminapi, transferworker, dashboard,
                                     # prometheus/alertmanager/loki/tempo/grafana/metabase
cd backend
cp ../.env.example ../.env           # root-level; edit DB_URL, REDIS_URL, NATS_URL, secrets
make sqlc                            # regenerate SQLC output
make proto                           # regenerate protobuf message types (internal DTOs)
make bff-gen                         # regenerate BFF strict server from OpenAPI
make migrate                         # apply 0001–0025
make test                            # unit tests
make test-integration                # testcontainers Postgres 16 — requires Docker
make bff                             # single HTTP binary on :8082 (docs at /docs)
```

Seed keys (one-off; all three are safe to re-run with fresh rows):

```sql
-- 1. Bank signing key. Generate the Ed25519 pair out-of-band (or use
--    opsctl rotate-bank-key once per-environment).
INSERT INTO bank_signing_keys (key_id, pubkey, privkey_enc, active_from)
VALUES ('bank-2026-04', E'\\x<32-byte-pubkey>', E'\\x<64-byte-privkey>', now());

-- 2. Realm key (AES-256, 32 bytes of CSPRNG output).
INSERT INTO realm_keys (version, key_enc, active_from)
VALUES (1, E'\\x<32-byte-key>', now());

-- 3. Server sealed-box X25519 key. Public → clients via GET /v1/keys/sealed-box-pubkey;
--    private lives in SERVER_SEALED_BOX_PRIVKEY env var on the BFF process.
```

System rows are created automatically by migrations:

- `system-settlement` user + `system-suspense` account (migration `0005`).
- `system-mint` user + `system-mint-treasury` (pre-funded ₦5B) + `system-mint-source` (counter-balance) (migration `0021`).
- Admin roles (`VIEWER`, `SUPPORT`, `FINANCE_OPS`, `FRAUD_OPS`, `SUPERADMIN`) seeded in migration `0014`. Seed a first admin with:

  ```bash
  go run ./cmd/opsctl admin-create --email you@example.com --name "You" --roles SUPERADMIN
  ```

## 2. Test tiers

| Command | Scope | Runtime |
|---------|-------|---------|
| `make test` | unit + in-memory fakes for every service | ~5s |
| `make test-integration` | build tag `integration`, testcontainers Postgres + Redis | ~90s |
| `make e2e` | `cmd/e2e` simulated txn run (tag `e2e`) | ~2 min |
| `make test-scale` | 100k-txn scale suite (tag `scale`, 15m timeout) | ~8–10 min |
| `cd mobile/packages/core && dart test` | Dart primitives + crosslang fixture | ~30s |
| `cd mobile/app && flutter test` | widget + service tests | ~15s |
| `make chaos-{nats,postgres,worker,all}` | kill/restart infra to exercise resume paths | minutes |

## 3. Key rotation

### 3.1 Bank signing key

Preferred:

```bash
go run ./cmd/opsctl rotate-bank-key
```

What it does: inserts a new `(key_id, pubkey, privkey_enc, active_from=now())` row and stamps the prior active row with `retired_at = now + overlap`. Both keys are returned from `POST /v1/keys/bank-public-keys` during the overlap window. Settlement resolves the verifier by `ceiling.bank_key_id` / `display_card.bank_key_id`, so overlap is inherent.

After the retired key's `retired_at` passes plus one ceiling TTL, hard-delete the private material:

```sql
UPDATE bank_signing_keys
   SET privkey_enc = NULL
 WHERE retired_at < now() - interval '24 hours';
```

### 3.2 Realm key

```bash
go run ./cmd/opsctl rotate-realm-key
```

Inserts the next `realm_keys` version, retires the previous active version with an overlap window (default 30 days), deletes expired rows. Devices pick up new versions on next `GET /v1/keys/realm/active`; in-flight QR streams decode against the retired version until the overlap elapses.

### 3.3 Sealed-box X25519 key

Keys are held in the BFF process, not Postgres. The gossip service tries the current key and every entry in `SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS` in order, so rotation is an env change:

1. `go run ./cmd/opsctl rotate-sealedbox-key` (or `cmd/rotate_sealedbox_key`) generates a new pair, writes the privkey to a file (mode 0600), prints the pubkey.
2. On the next BFF deploy: promote the new privkey to `SERVER_SEALED_BOX_PRIVKEY`; append the previous value to `SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS` (comma-separated).
3. Clients fetch the new pubkey from `GET /v1/keys/sealed-box-pubkey` on next online sync.
4. After `CEILING_TTL_HOURS + AUTO_SETTLE_TIMEOUT_HOURS` (default 24h + 72h = 96h), drop the retired privkey from `SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS`.

### 3.4 Device-session (DST) key

```bash
go run ./cmd/opsctl gen-device-session-key
# or:
go run ./cmd/opsctl gen-device-session-key \
    --key-id=device-session-2026q2 --ttl-hours=336
```

Prints the `BFF_DEVICE_SESSION_PRIVKEY` / `BFF_DEVICE_SESSION_KEY_ID` / `BFF_DEVICE_SESSION_TTL_HOURS` env block. The device verifies tokens locally against the cached pubkey set from `GET /v1/auth/device-session/public-keys`; rotation semantics and failure modes are documented in `docs/OFFLINE_AUTH.md` § Operations.

## 4. Nightly reconciliation job

Entrypoint: `reconciliation.Service.NightlyLedgerReconcile` (`backend/internal/service/reconciliation/service.go`).

The BFF runs a goroutine that calls this at 03:00 UTC — no external cron required. If you'd rather run it out-of-process (for example, against a replica), invoke the CLI instead:

```bash
go run ./cmd/opsctl recon-now
```

The job writes one row to `reconciliation_runs` per run with `status = CLEAN` or `DISCREPANCY`. Per-discrepancy JSON is stored in the same row.

## 5. Triaging a discrepancy alert

The reconciler flags two kinds of mismatch:

1. **`account_balance:<id>:<kind>`** — stored `balance_kobo` disagrees with `sum(credits) - sum(debits)` in `ledger_entries`. Severity `CRITICAL`.
2. **`ceiling_overdraw:<ceiling_id>`** — settled payments sum exceeds the ceiling amount. Severity `CRITICAL`.

Queries for an account imbalance on `acct-abc`:

```sql
SELECT direction, SUM(amount_kobo)
  FROM ledger_entries WHERE account_id = 'acct-abc'
  GROUP BY direction;

SELECT id, user_id, kind, balance_kobo
  FROM accounts WHERE id = 'acct-abc';

SELECT txn_id, direction, amount_kobo, memo, created_at
  FROM ledger_entries WHERE account_id = 'acct-abc'
  ORDER BY created_at DESC LIMIT 50;

-- The user-facing event log for the same account's owner:
SELECT id, kind, status, direction, amount_kobo, settled_amount_kobo,
       payment_token_id, transfer_id, ceiling_id, group_id, created_at
  FROM transactions
 WHERE user_id = (SELECT user_id FROM accounts WHERE id = 'acct-abc')
 ORDER BY created_at DESC LIMIT 50;
```

For a ceiling overdraw on `ceil-xyz`:

```sql
SELECT id, payer_user_id, ceiling_kobo, status, release_after
  FROM ceiling_tokens WHERE id = 'ceil-xyz';

SELECT status, SUM(settled_amount_kobo)
  FROM payment_tokens WHERE ceiling_id = 'ceil-xyz'
  GROUP BY status;
```

If the overdraw is real, freeze the payer (see §7) and escalate — this indicates a settlement invariant broke.

## 6. Alerting thresholds (suggested)

| Signal | Threshold | Action |
|--------|-----------|--------|
| `reconciliation_runs.status = 'DISCREPANCY'` | any | page on-call |
| `system-suspense.balance_kobo` non-zero > 15min | sustained | investigate incomplete 4b |
| Pending payments older than `AutoSettleTimeout - 1h` | > 1000 | capacity / stuck payer sync |
| `fraud_signals` insert rate for one `user_id` | > 10 / 5min | freeze candidate |
| `FundOffline` p99 latency | > 2s | DB hotspot |
| `SubmitClaim` rejection rate | > 5% over 10min | possible key mismatch / rotation bug |
| `outbox` lag (oldest un-dispatched event age) | > 30s | dispatcher stuck; check `cmd/transferworker` |
| `ceiling_tokens.status = 'RECOVERY_PENDING'` with `release_after < now()` and count > 0 | > 0 for > 15min | `ReleaseOnExpiry` not running |

Grafana dashboards and Alertmanager rules live in `ops/grafana/` and `ops/alertmanager/`.

## 7. Emergency procedures

### 7.1 Freeze a user's ceiling

```sql
BEGIN;
UPDATE ceiling_tokens
   SET status = 'REVOKED'
 WHERE payer_user_id = '<uid>' AND status IN ('ACTIVE', 'RECOVERY_PENDING');

-- Record the incident so fraud scoring demotes the tier.
INSERT INTO fraud_signals (id, user_id, signal_type, severity, details, weight, created_at)
VALUES (gen_random_uuid()::text, '<uid>', 'SIGNATURE_INVALID', 'HIGH',
        'operator freeze', 0.7, now());
COMMIT;
```

Or via the CLI:

```bash
go run ./cmd/opsctl freeze-user --user <uid>
```

Revoking does **not** automatically release the lien — call `wallet.MoveToMain(uid)` once you're sure no in-flight claims remain, or wait for `ReleaseOnExpiry` at `expires_at + 30min`.

### 7.2 Force-expire a ceiling

Safer than revoke if claims may still be arriving:

```bash
go run ./cmd/opsctl force-expire-ceiling --ceiling <id>
```

Then next `wallet.Service.ReleaseOnExpiry` tick sweeps it.

### 7.3 Ceiling recovery (user lost the device)

The first-class flow. Triggered by the user via `POST /v1/wallet/recover-offline-ceiling`; the sweep releases the lien once `release_after` elapses. If you must kick the sweep manually:

```bash
go run ./cmd/opsctl release-lien
```

This runs `wallet.ReleaseOnExpiry` once — safe, idempotent.

### 7.4 Manually release a lien

Only when you've verified there are no in-flight unsettled claims:

```sql
SELECT COUNT(*) FROM payment_tokens
 WHERE ceiling_id = '<ceiling-id>'
   AND status IN ('SUBMITTED', 'PENDING');   -- must be 0
```

Then call `opsctl release-lien` or `wallet.Service.MoveToMain(userID)` via the authenticated endpoint. If you have to do it by hand, replicate the ledger block in `releaseCeiling` (`backend/internal/service/wallet/service.go`) inside a single tx — mis-ordering the legs will trip the double-entry constraint.

## 8. Operational tips

- `system-suspense` is exempt from the non-negative CHECK (migration `0005`). A non-zero value outside a 4a→4b window is a *bug*, not a balance error.
- Never manually insert into `ledger_entries` — always go through `pgrepo.Repo.PostLedger`, which keeps the `SUM(debit) = SUM(credit)` trigger happy. Every mutation path also writes a `transactions` row (migration `0018`); hand-writing ledger legs without the matching transaction row will trip the deferred `fk_ledger_txn` FK.
- Redis is best-effort cache-aside. The source of truth for double-spend is the `(payer_user_id, sequence_number)` unique index. A flushed Redis is not a crisis.
- The gossip endpoint is idempotent — re-uploading the same blob is a no-op (dedupes on `(payer_user_id, sequence_number)` and on the `(payee_user_id, session_nonce)` PR index).
- `cmd/transferworker` drains the outbox and mutates balances in a separate process. If it's behind, online transfers won't settle; the BFF response is still synchronous (the transfer row is written, then published).
- The backoffice dashboard and the BFF are separate processes with separate JWT secrets. Revoking a user JWT does not revoke an admin session and vice versa.
- If you change any migration under `db/migrations/`, rebuild *every* binary that sets `MIGRATE_ON_BOOT=true` in the same deploy — otherwise `schema_migrations` and the actual schema desync.
