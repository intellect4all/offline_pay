# Offline-Pay Backend — Engineering Documentation

Go backend for an offline-first QR payment system for Nigeria. Cryptographic stored-value ceiling tokens, receiver-issued PaymentRequests, two-phase settlement, gossip propagation, two-layer encryption, bank-signed identity credentials. A single HTTP binary speaks the OpenAPI contract to Flutter; all settlement, wallet, gossip, identity, and registration logic runs in-process alongside it.

For product / architecture intent, start with `../CLAUDE.md` and the top-level `../docs/`. This document focuses on *how the Go code is organised and operated*.

---

## 1. Repository layout

```
backend/
├── cmd/                # Binary entry points
├── internal/           # Private packages
├── pkg/
│   └── qr/             # Animated-QR framing/encoding
├── proto/              # Protobuf message types (internal DTOs only)
├── api/                # OpenAPI 3.1 spec + embed.go (served by BFF at /openapi.yaml)
├── db/
│   ├── migrations/     # 0001–0025 up+down SQL
│   └── queries/        # SQLC input queries
├── ops/
│   └── git-hooks/      # Local pre-commit substitute for remote CI
├── Dockerfile.bff
├── Dockerfile.adminapi
├── Dockerfile.transferworker
├── Makefile
├── buf.yaml / buf.gen.yaml
├── sqlc.yaml
└── go.mod / go.sum
```

There is no gRPC wire transport and no API gateway. The prior `cmd/server` and Tyk layer were collapsed into the BFF during PoC cleanup. Protobuf types survive as internal DTOs; the handlers under `internal/transport/grpc/server/` are plain Go structs invoked directly by BFF HTTP handlers.

---

## 2. Binaries (`cmd/`)

### 2.1 `cmd/bff` — single HTTP API for Flutter clients

The only client-facing binary. Exposes the REST JSON API from `api/openapi.yaml`, runs wallet / settlement / gossip / reconciliation / identity / registration logic in-process, and drives the background cron loops.

| Aspect | Value |
|---|---|
| Protocol | HTTP/1.1 + JSON (OpenAPI 3.1) |
| Default port | `:8082` |
| Container | `Dockerfile.bff` |
| OpenAPI spec | `GET /openapi.yaml` |
| Swagger UI | `GET /docs` |
| Generated handlers | `internal/transport/http/bff/gen` via `oapi-codegen` |

**Endpoint groups** (see `docs/API.md` for the narrative, `api/openapi.yaml` for the contract):

- `/v1/auth/*` — signup, login, refresh, logout, PIN, sessions (list, revoke, revoke-all-others), email verification, forgot-password, device-session token issuance + public keys.
- `/v1/identity/display-card` — fetch the caller's current bank-signed DisplayCard.
- `/v1/me`, `/v1/accounts/resolve/{accountNumber}`, `/v1/kyc/*`.
- `/v1/transfers[/{id}]` — online P2P transfers (outbox-backed).
- `/v1/wallet/*` — fund offline, balances, ceiling/current, move to main, refresh ceiling, recover ceiling, dev top-up.
- `/v1/settlement/*` — submit claim (4a), batch receipt, sync (+finalize), gossip upload.
- `/v1/devices/*`, `/v1/keys/*` — device registration, attestation, push-token, bank/realm/sealed-box key lookups.
- `/demo/*` — dev-only funding page (feature-flagged).

**In-process services wired on the `Handler`:**

| Field | Source |
|---|---|
| `Handler.Wallet` | `*server.WalletServer` wrapping `wallet.Service` |
| `Handler.Settlement` | `*server.SettlementServer` wrapping `settlement`, `reconciliation`, `gossip` |
| `Handler.Keys` | `*server.KeysServer` over `pgrepo.Repo` + sealed-box key |
| `Handler.Registration` | `*server.RegistrationServer` with attestation hooks |
| `Handler.Identity` | `identity.Service` — DisplayCard issuance |
| `Handler.Auth` / `Transfers` / `Accounts` / `KYC` | BFF-native services |

The `internal/transport/grpc/server` package does not speak gRPC — it is a thin marshalling layer between protobuf DTOs and domain types. `server.WithAuthUser` and `server.WithSubmitterCountry` carry request-scope data into these handlers.

**Background crons** (goroutines started in `run()`):

- `wallet.ReleaseOnExpiry` every 5m — releases liens on expired and `RECOVERY_PENDING` ceilings past their `release_after`.
- `settlement.AutoSettleSweep` every 15m — forces `PENDING` txns past the 72h timeout into a terminal state.
- `reconciliation.NightlyLedgerReconcile` daily at 03:00 UTC — double-entry audit.

**Auth model**: phone + password signup/login → JWT access token (HMAC-SHA256, short TTL) + refresh token persisted in `user_sessions`. Route-level enforcement via a single middleware wrapper in `cmd/bff/main.go`; `sub` claim is the user id. A second, server-signed Ed25519 `DST` (device-session) powers the offline cold-start unlock described in `../docs/OFFLINE_AUTH.md`.

**Key env vars** (see `cmd/bff/config.go`):

- `OFFLINEPAY_ENV` — `local` | `production` (production refuses insecure defaults).
- `DB_URL`, `REDIS_URL` (optional — empty or unreachable → `cache.Noop` fallback).
- `BFF_HTTP_ADDR`, `BFF_JWT_SECRET` (≥32 bytes in prod), `BFF_JWT_AUDIENCE`.
- `BFF_ACCESS_TTL_MINUTES`, `BFF_REFRESH_TTL_HOURS`, `BFF_OTP_TTL_MINUTES`, `BFF_OTP_MAX_ATTEMPTS`.
- `BFF_RATE_LIMIT_RPS`, `BFF_RATE_LIMIT_BURST`.
- `CEILING_TTL_HOURS`, `AUTO_SETTLE_TIMEOUT_HOURS`, `CLOCK_GRACE_MINUTES`.
- `SERVER_SEALED_BOX_PRIVKEY` — hex X25519 for gossip blob decrypt; auto-generated in dev.
- `SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS` — comma-separated retired keys (decrypt-only overlap window).
- `CRYPTO_SIGNER` — `local` (Postgres-backed) or `vault` (HashiCorp Vault transit).
- `VAULT_ADDR`, `VAULT_TOKEN`, `VAULT_TRANSIT_MOUNT`.
- `ATTESTATION_MODE` — `dev` | `production`.
- `BFF_ENABLE_DEV_TOPUP`, `BFF_ENABLE_DEMO_MINT`.
- `BFF_DEVICE_SESSION_PRIVKEY`, `BFF_DEVICE_SESSION_KEY_ID`, `BFF_DEVICE_SESSION_TTL_HOURS`.
- `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`, `MIGRATE_ON_BOOT`.

### 2.2 `cmd/adminapi` — Backoffice REST API

Powers the Nuxt admin dashboard. Email + bcrypt login, JWT access tokens, refresh sessions persisted in `admin_sessions`. RBAC with five seeded roles (`VIEWER`, `SUPPORT`, `FINANCE_OPS`, `FRAUD_OPS`, `SUPERADMIN`). Every mutating action writes to `admin_audit_log`.

| Aspect | Value |
|---|---|
| Default port | `:8081` |
| Container | `Dockerfile.adminapi` |

**Key env vars**: `ADMIN_HTTP_ADDR`, `ADMIN_JWT_SECRET` (≥32B), `ADMIN_JWT_AUDIENCE`, `ADMIN_CORS_ORIGIN`, `ADMIN_ACCESS_TTL_MINUTES`, `ADMIN_REFRESH_TTL_HOURS`.

### 2.3 `cmd/transferworker` — Async transfer processor

Implements the **transactional outbox** pattern for user-to-user transfers.

1. BFF writes `transfers` row + `outbox` entry in one DB transaction.
2. Dispatcher polls `outbox`, publishes to NATS JetStream (`payments.transfer.v1`).
3. Processor consumes from JetStream, mutates sender/receiver balances under a serializable transaction, records `processed_events` for idempotency.

| Aspect | Value |
|---|---|
| Default metrics port | `:9102` |
| Container | `Dockerfile.transferworker` |

**Key env vars**: `NATS_URL`, `DB_URL`, `WORKER_BATCH_SIZE` (default 16), `WORKER_DISPATCH_INTERVAL_MS` (default 500), `WORKER_METRICS_ADDR`.

### 2.4 Operational CLIs

- **`cmd/opsctl`** — ad-hoc rituals. Subcommands: `rotate-realm-key`, `rotate-bank-key`, `rotate-sealedbox-key`, `gen-device-session-key`, `force-expire-ceiling`, `release-lien`, `freeze-user`, `recon-now`, `admin-create`.
- **`cmd/rotate_realm_key`** — the standalone older CLI that mints the next `realm_keys` version (superseded by `opsctl rotate-realm-key`; kept for build compatibility).
- **`cmd/rotate_sealedbox_key`** — generates a fresh X25519 keypair for gossip blob encryption. Writes privkey to file (mode 0600), public key to stdout, with promotion instructions. Flag: `--out`.
- **`cmd/opsim`** — in-process settlement simulator. Spins up `pgrepo` + `wallet` + `settlement` against a live Postgres, registers synthetic payers + merchants, drives `FundOffline` → payment → claim → finalise, prints a summary with settled volume, ledger deltas, and a reconciliation check. Useful for sanity-testing schema changes.

### 2.5 `cmd/e2e` — Integration & scale suite

Build-tagged tests: `e2e`, `integration`, `scale`.

- `harness_test.go` — in-process service setup (no gRPC).
- `sessions_e2e_test.go` — full offline payment journeys.
- `scale_test.go` — 100k-transaction stress run (tag `scale`, 15m timeout).

Invoked by `make e2e` and `make test-scale`.

---

## 3. Internal packages (`internal/`)

### 3.1 `internal/domain` — Pure domain models

Zero external deps beyond stdlib. All money is `int64` kobo (no floats, no decimals).

| File | Key types |
|---|---|
| `user.go`, `user_transaction.go` | `User`, KYC tier, business-event log rows. |
| `wallet.go` | `Wallet`, `OfflineWallet` (legacy name; derived on-device), `Lien`, `LienStatus`, `OfflineWalletStatus`. |
| `ceiling.go` | `CeilingToken`, `CeilingTokenPayload`, `CeilingStatus` (incl. `RECOVERY_PENDING`), `BankSigningKey`, `ReleaseAfter`. |
| `payment.go` | `PaymentToken`, `PaymentPayload` (with `SessionNonce` + `RequestHash`). |
| `payment_request.go` | `PaymentRequest`, `PaymentRequestPayload`, `UnboundAmount`, validation. |
| `display_card.go` | `DisplayCard`, `DisplayCardPayload`. |
| `transaction.go` | `Transaction`, `TransactionStatus`, `ValidTransitions`. |
| `settlement.go` | `SettlementBatch` (carries `ReceiverID`), `SettlementBatchStatus`, `SettlementResult`, `MerchantBalance` (legacy type name; holds a receiver's pending + available figures). |
| `gossip.go` | `GossipBlob`, `GossipManifest`, `GossipPayload`, `GossipEnvelope`, `MaxGossipHops`. |
| `fraud.go` | `FraudEvent`, `FraudSignalType`, `FraudTier`. |
| `reconciliation.go` | `ReconRun`, `ReconStatus`, `Discrepancy`. |
| `transfer.go` | `Transfer`, `TransferStatus`, validators. |
| `outbox.go` | `OutboxEvent`. |
| `crypto.go` | `CipherSuiteVersion`, `QRFrameFormat`. |

**State machines enforced in domain code**:

- `TransactionStatus`: `QUEUED → SUBMITTED → PENDING → SETTLED | PARTIALLY_SETTLED | REJECTED`, or `EXPIRED`.
- `CeilingStatus`: `ACTIVE → RECOVERY_PENDING → REVOKED` or `ACTIVE → EXPIRED | EXHAUSTED | REVOKED`.
- `LienStatus`: `ACTIVE → SETTLED | RELEASED | PARTIAL`.

### 3.2 `internal/service` — Business logic

Stateless services. All write paths wrap in `Repo.Tx(ctx, fn)` which runs under PostgreSQL `SERIALIZABLE` isolation.

| Package | Purpose |
|---|---|
| `wallet` | Ceiling issuance, lien lifecycle, balance views, expiry sweeps, recovery flow. |
| `settlement` | Phase 4a (`SubmitClaim`), Phase 4b (`FinalizeForPayer`), conflict resolution, `AutoSettleSweep`. Verifies bank + payer + DisplayCard + PR signatures and the PR/token hash binding. |
| `gossip` | Decrypts relayed blobs with server X25519 keys (primary + overlap); re-routes to settlement. |
| `reconciliation` | `SyncUser`, `BatchReceipt`, nightly ledger audit. |
| `fraud` | Signal recording + weighted/decayed scoring → `FraudTier`; transfer-fraud scoring surface (separate table). |
| `transfer` | Idempotent user-to-user transfer initiation (writes outbox). |
| `userauth` | Signup/login, OTP, JWT issuance + refresh, PIN + session management, device-session (DST) minting. |
| `account` | Account lookup + balance views. |
| `kyc` | BVN / NIN submission, hint, admin-facing listing. |
| `admin` | Backoffice login, session mgmt, admin ops, audit log. |
| `identity` | `IssueDisplayCard` — server-signed identity credential for PRs. |
| `demomint` | Demo treasury funding (dev-only). |
| `registration` | Device registration + attestation hooks (dev-mode complete, production verifiers wired). |
| `notification` | FCM dispatch for push events. |

Each service defines a narrow `Repo` interface and depends on it; the concrete repository is adapted in a per-package `pgrepo_adapter.go`. This keeps services unit-testable against fakes and keeps SQL out of service code.

### 3.3 `internal/repository`

| Subpackage | Role |
|---|---|
| `pgrepo` | Primary repo over `pgx` + `sqlcgen.Queries`. Exposes domain-typed methods and `Tx(ctx, fn)`. The only package that deals in generated query types. |
| `userauthrepo` | Auth-domain repo (sessions, OTP, user-me reads) — same pool, separate struct. |
| `transferrepo` | Transfer-service reads (receiver resolution, KYC tier). |
| `accountrepo`, `kycrepo`, `adminrepo`, `fraudrepo`, `opsrepo` | Narrow per-service adapters. |
| `sqlcgen` | SQLC-generated code (do not edit). Regenerated by `make sqlc`. |
| `migrate` | `golang-migrate` wrapper with migrations embedded via `embed.FS`. |
| *(above repos all take a)* `internal/cache` | Optional Redis cache-aside. Six hot-path reads cached: device auth, user KYC tier, receiver resolution by account number, active bank key, active realm keys (single + list), user account number, user `GetMe`. Falls back to `cache.Noop` when `REDIS_URL` is empty. |

### 3.4 `internal/crypto`

| File | Contents |
|---|---|
| `ed25519.go` | `Sign` / `Verify` pairs for ceiling, payment, request, and display-card payloads. `*WithSigner` variants delegate to `CeilingSigner` for KMS-backed signing. |
| `sealed_box.go` | NaCl `crypto_box_seal` — gossip blob encryption (X25519). |
| `aes_gcm.go` | AES-256-GCM — realm-key QR payload encryption; `DeriveFrameNonce`. |
| `canonical.go` | Deterministic JSON encoding for signatures (fuzz-tested; matches the Dart implementation byte-for-byte). |
| `kms/` | `LocalSigner` (Postgres key storage) and `VaultSigner` (HashiCorp Vault Transit) behind a shared `Signer` interface. |

### 3.5 `internal/transport`

| Path | Role |
|---|---|
| `grpc/gen/` | `buf generate`'d protobuf message types — used as internal Go DTOs only. |
| `grpc/server/` | In-process handlers (Wallet/Settlement/Keys/Registration) + auth/country context helpers + domain↔proto mappers. |
| `http/bff/` | BFF handlers wired to the `oapi-codegen`-generated strict server. |
| `http/bff/gen/` | Generated OpenAPI server + types. |
| `http/bff/demo/` | Dev-only funding page. |
| `http/admin/` | Admin REST handlers (stdlib mux). |

The `grpc/server` name is historical — the package no longer runs gRPC. Its handler methods are invoked directly by BFF HTTP handlers and take context values (`AuthUser`, submitter country) that the HTTP layer stamps onto the context before dispatch.

### 3.6 Other internal packages

- `internal/auth` — JWT issuance/validation for user and admin tokens; device-session token crypto (pure, no I/O).
- `internal/config` — shared env-loading helpers (used by `cmd/opsctl`).
- `internal/logging` — `slog` setup (level + JSON/text format via env).
- `internal/observability` — OpenTelemetry tracing (OTLP) + Prometheus metrics glue.

### 3.7 `pkg/qr`

Animated-QR framing: header frame, chunk frames with `frame_index`, trailer checksum. Per-frame AES-GCM nonce is `base_nonce + frame_index`. Target 10–15 fps, ~2 KB/frame, ~72 KB total payload capacity.

---

## 4. Protobuf (`proto/offlinepay/v1/`)

Message types compiled with `buf generate` into `internal/transport/grpc/gen`. Internal Go DTOs only — there is no wire-level gRPC.

| File | Messages |
|---|---|
| `wallet.proto` | `FundOffline`, `GetBalances`, `MoveToMain`, `RefreshCeiling`, `RecoverOfflineCeiling`, `CurrentCeiling` request/response. |
| `settlement.proto` | `SubmitClaim`, `GetBatchReceipt`, `SyncUser`, `GossipUpload` request/response. |
| `keys.proto` | Bank public keys, realm keys, sealed-box pubkey. |
| `registration.proto` | Device register / attest / deactivate / rotate / revoke / recover. |
| `common.proto` | `TransactionStatus`, `CeilingStatus`, `AccountKind`, `SettlementBatchStatus` enums; wire messages for `CeilingToken`, `PaymentToken`, `PaymentRequest`, `DisplayCard`, `GossipBlob`, `BatchReceipt`, `AccountBalance`, `SettlementResult`. |

---

## 5. Database (`db/`)

PostgreSQL, accessed via `pgx/v5` with SQLC-compiled queries. No ORM.

### 5.1 Migrations (`db/migrations/`)

Numbered 0001–0025, each with up + down pairs. Order matters.

| # | File | Purpose |
|---|---|---|
| 0001 | `users` | Identity, KYC tier (`TIER_0..TIER_3`, `SYSTEM`), realm_key_version, optional BVN. |
| 0002 | `user_pins` | Separate PIN table with attempts counter + 15-min lockout. |
| 0003 | `signing_keys` | Payer Ed25519 pubkey rotation (device-bound). |
| 0004 | `devices` | One active device per user; attestation blob + platform + verified timestamp. |
| 0005 | `accounts` | Three kinds per user (`main`, `lien_holding`, `receiving_pending`); system-owned `suspense`. Seeds `system-settlement` user + `system-suspense` account. |
| 0006 | `ledger_entries` | Double-entry ledger; deferred constraint trigger enforces debits = credits at COMMIT. FK `txn_id → transactions.id` added in 0018. |
| 0007 | `bank_signing_keys` | Ed25519 key rotation (`active_from`, `retired_at`). |
| 0008 | `realm_keys` | AES-256-GCM versioned keys with overlap windows. |
| 0009 | `ceiling_tokens` | Bank-signed offline-spending authorisation; unique index for one live ceiling per user (extended in 0023). |
| 0010 | `payment_tokens` | Offline payment tokens; `UNIQUE (payer_user_id, sequence_number)`; `CHECK payer <> payee`. |
| 0011 | `fraud_signals` | Typed offline/cryptographic anomaly signals. |
| 0012 | `reconciliation_runs` | Payer / merchant / ledger run history with discrepancy JSON. |
| 0013 | `kyc_submissions` | BVN / NIN workflow. |
| 0014 | `admin_users`, `admin_roles`, `admin_user_roles`, `admin_sessions`, `admin_audit_log` | Backoffice surface + 5 seeded roles. |
| 0015 | `user_sessions`, `otp_challenges` | End-user refresh sessions + email-OTP state. |
| 0016 | `transfers`, `outbox`, `processed_events` | Transactional outbox for online P2P transfers. |
| 0017 | `fraud_scores` | Online-transfer fraud scoring stream. |
| 0018 | `transactions` | Business-event log; one row per affected user per event; FK installed on `ledger_entries.txn_id`. |
| 0019 | `push_tokens` | FCM registry. |
| 0020 | `demo_mint_kind` | Adds `DEMO_MINT` to `transaction_kind` enum. |
| 0021 | `demo_mint_treasury` | Seeds `system-mint` user + `system-mint-treasury` (₦5B) + counterweight. |
| 0022 | `ceiling_recovery` | Adds `RECOVERY_PENDING` + `release_after` + `OFFLINE_RECOVERY_RELEASE`. |
| 0023 | `ceiling_recovery_indexes` | Broadens "one live ceiling per user" across `ACTIVE` + `RECOVERY_PENDING`, adds sweep index. |
| 0024 | `payment_request_binding` | Adds `session_nonce`, `request_hash`, `request_amount_kobo` on `payment_tokens` + `UNIQUE (payee_user_id, session_nonce)`. |
| 0025 | `payment_submitted_by` | `submitted_by_user_id` attribution. |

### 5.2 Queries (`db/queries/*.sql`)

~100+ named queries across 21 files (`accounts`, `admin`, `admin_audit`, `admin_sessions`, `bank_keys`, `ceilings`, `devices`, `fraud`, `kyc`, `ledger`, `outbox`, `payments`, `processed_events`, `push_tokens`, `realm_keys`, `reconciliation`, `signing_keys`, `transactions`, `transfers`, `user_auth`, `user_pins`, `users`). SQLC generates typed Go code with `emit_json_tags=true` into `internal/repository/sqlcgen`. Regenerate with `make sqlc`.

---

## 6. REST API (`api/openapi.yaml`)

OpenAPI 3.1. The hand-written spec (~3k lines) is the source of truth. The BFF embeds it and serves:

- `GET /openapi.yaml` — raw spec.
- `GET /docs` — Swagger UI.

Regenerate server handlers with `make bff-gen`; regenerate the Dart SDK for the mobile app with `make flutter-client-gen`.

Endpoint groups (keyless vs JWT-protected): see `../docs/API.md` for the full matrix.

---

## 7. Cryptography (operational view)

| Layer | Primitive | Key source | Rotation |
|---|---|---|---|
| Bank signature on ceilings + DisplayCards | Ed25519 | `bank_signing_keys` or Vault (`CRYPTO_SIGNER`) | `opsctl rotate-bank-key` |
| Payer signature on payment tokens | Ed25519 | Device keystore (platform HSM / `flutter_secure_storage`); pubkey persisted in `signing_keys` and snapshotted onto each ceiling | At registration; user-level. |
| Receiver signature on `PaymentRequest` | Ed25519 | Same device key as above (receiver role). | Same. |
| QR/NFC payload (Layer 1) | AES-256-GCM | `realm_keys` (versioned, with overlap) | `opsctl rotate-realm-key` |
| Gossip blob (Layer 2) | X25519 sealed box | BFF process keypair from `SERVER_SEALED_BOX_PRIVKEY` | `opsctl rotate-sealedbox-key`; retired keys listed in `SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS` |
| Device-session (DST) | Ed25519 | BFF-held key from `BFF_DEVICE_SESSION_PRIVKEY` | `opsctl gen-device-session-key` |

Canonical JSON (`internal/crypto/canonical.go`) must produce byte-identical output across Go and Dart — any change here breaks signature verification between backend and mobile.

---

## 8. Build, test, generate (`Makefile`)

Canonical targets — prefer these over ad-hoc `go` commands.

| Target | What it does |
|---|---|
| `test` | Unit tests (`-race -count=1`). |
| `test-integration` | Repo + cache tests against Postgres 16 / Redis 7 via testcontainers (tag `integration`). |
| `test-scale` | 100k-txn scale suite (tag `scale`, 15m timeout). |
| `e2e` | End-to-end suite (tag `e2e`, 5m timeout); writes `docs/stress-report.md` when `WRITE_STRESS_REPORT=1`. |
| `check` | Fast sanity: `vet` + unit + dart tests (matches pre-commit hook). |
| `check-all` | `check` + integration + e2e. |
| `vet`, `lint`, `fmt`, `tidy` | Static analysis + formatting. |
| `sqlc` | Regenerate SQLC (`internal/repository/sqlcgen/`). |
| `proto` | Regenerate protobuf message types (`internal/transport/grpc/gen/`). |
| `bff-gen` | Regenerate BFF server from OpenAPI. |
| `flutter-client-gen` | Regenerate Dart SDK from OpenAPI. |
| `migrate` / `migrate-down` | Apply / roll back one migration. |
| `bff`, `adminapi`, `transferworker` | Run the named binary. |
| `*-build` | Build binaries into `bin/`. |
| `chaos-{nats,postgres,worker,all}` | Run chaos scripts under `../ops/chaos/`. |
| `install-hooks` | Symlink the local pre-commit hook (substitutes for remote CI in the PoC). |

Code-generation inputs and their outputs:

- `proto/**/*.proto` → `internal/transport/grpc/gen/` (via `buf` + `buf.gen.yaml`).
- `db/queries/*.sql` + `db/migrations/` → `internal/repository/sqlcgen/` (via `sqlc`).
- `api/openapi.yaml` → `internal/transport/http/bff/gen/` (via `oapi-codegen`) and `../mobile/packages/offlinepay_api/` (Dart client).

---

## 9. Containers & deployment

Three multi-stage Dockerfiles, all producing distroless nonroot images with statically linked binaries (`CGO_ENABLED=0`).

| Dockerfile | Binary | Exposed ports |
|---|---|---|
| `Dockerfile.bff` | `bff` | 8082 |
| `Dockerfile.adminapi` | `adminapi` | 8081 |
| `Dockerfile.transferworker` | `transferworker` | 9102 (metrics only) |

`ops/git-hooks/pre-commit` runs `go vet`, `go test`, and the Dart mobile tests as a local CI substitute.

`docker-compose.yml` at the repo root wires up the full local stack: Postgres, Redis, NATS, BFF, adminapi, transferworker, dashboard, plus Prometheus, Alertmanager, Loki, Promtail, Tempo, Grafana, and Metabase.

---

## 10. Request walkthroughs

### 10.1 Fund the offline wallet

1. Flutter client calls `POST /v1/wallet/fund-offline` on the BFF (auth required).
2. BFF validates JWT, stamps the auth user onto the context, and calls `Handler.Wallet.FundOffline` — a plain method call on the in-process `WalletServer`.
3. `wallet.Service.FundOffline` opens `Repo.Tx` (SERIALIZABLE):
   - Debits `main_A`, credits `lien_holding_A` (creates a `Lien`).
   - Signs a new `CeilingTokenPayload` with the active bank key (local Postgres or Vault signer).
   - Inserts `ceiling_tokens` row (`ACTIVE`, one-live-per-user enforced by the partial unique index).
   - Writes a `transactions` row (`OFFLINE_FUND`, `COMPLETED`).
   - Posts balanced ledger entries against the transaction id.
4. Response returns the signed `CeilingToken` for the device to cache offline.

### 10.2 Receiver-led offline payment → settlement

1. **Offline**:
   - Receiver's device generates a `PaymentRequest` (`session_nonce`, `expires_at`, amount or unbound sentinel), signs with their device key, embeds the current bank-signed `DisplayCard`.
   - Payer scans the PR, verifies the server sig on the DisplayCard and the receiver sig on the PR. Builds a `PaymentToken` with monotonic `sequence_number`, `session_nonce` copied from the PR, `request_hash = SHA-256(canonical(PR))`, signs with the HSM key.
   - Payer's device builds a `GossipEnvelope` (payment + ceiling + blobs), AES-256-GCM-seals with the active realm key, renders animated QR or stages NFC APDU chunks.
   - Receiver scans/taps, reassembles, decrypts, re-verifies the whole chain (bank → payer → DisplayCard → receiver → PR/token binding), queues the triple locally in SQLite.
2. **Phase 4a** (either side online): client calls `POST /v1/settlement/claims` with `{tokens, ceilings, requests}`. The BFF dispatches to `Handler.Settlement.SubmitClaim`, which re-runs every signature check, verifies the `request_hash`, enforces `submitter ∈ {payer, payee}`, orders by sequence number, resolves conflicts, records `payment_tokens` rows as `PENDING`, writes Phase-4a `transactions` rows, credits `receiving_pending_B`. Returns a `BatchReceipt`.
3. **Phase 4b** (payer online, or auto-sweep after 72h): `FinalizeForPayer` (via `POST /v1/settlement/sync` with `finalize: true`) or the `AutoSettleSweep` cron debits `lien_holding_A`, drains `receiving_pending_B` into `main_B`. Terminal states: `SETTLED`, `PARTIALLY_SETTLED`, or `REJECTED`.

### 10.3 Gossip propagation

Every payment QR/NFC envelope also carries up to 500 encrypted gossip blobs (X25519 sealed box, server-only decrypt). Whichever participant comes online first uploads the bundle via `POST /v1/settlement/gossip`; `gossip.Service` decrypts and forwards each blob to `settlement.Service.SubmitClaim` for normal Phase-4a processing. Hop limit 3; dedup via Bloom filter on-device and `(payer_user_id, sequence_number)` / `(payee_user_id, session_nonce)` on the server.

### 10.4 User-to-user transfer (online)

1. `POST /v1/transfers` on the BFF → `transfer.Service.InitiateTransfer`. PIN check, KYC + fraud gate.
2. In one DB transaction: create `transfers` row + `outbox` entry + two paired `transactions` rows. Response is immediate; transfer is `PENDING`.
3. `transferworker`'s dispatcher polls `outbox`, publishes to NATS JetStream `payments.transfer.v1`.
4. Processor consumes, runs balance mutation under `SERIALIZABLE`, writes `processed_events` for idempotency, marks the transfer `SETTLED` and the paired transactions `COMPLETED`.

### 10.5 Ceiling recovery

1. User on a replacement device calls `POST /v1/wallet/recover-offline-ceiling`.
2. `wallet.Service.RecoverOfflineCeiling` marks the active ceiling `RECOVERY_PENDING` and stamps `release_after = expires_at + AutoSettleTimeout + ClockGrace`. The lien remains locked.
3. In-flight merchant claims still land — `submitOne`'s dedupe at `(payer, sequence)` admits them even after the ceiling leaves `ACTIVE` because the dedupe runs before the liveness check.
4. After `release_after`, `ReleaseOnExpiry` drains the remaining lien to `main_A`, writes an `OFFLINE_RECOVERY_RELEASE` transaction, and marks the ceiling `REVOKED`.

---

## 11. Local development

Minimal loop:

```bash
docker compose up -d postgres redis nats
export DB_URL='postgres://offlinepay:offlinepay@localhost:5432/offlinepay?sslmode=disable'
export REDIS_URL='redis://localhost:6379/0'
export NATS_URL='nats://localhost:4222'

make migrate                     # apply 0001–0025
make bff                         # cmd/bff on :8082 (HTTP + docs at /docs)
make adminapi                    # cmd/adminapi on :8081
make transferworker              # cmd/transferworker (metrics :9102)

make check                       # vet + unit + dart tests (fast)
make check-all                   # + integration + e2e (slow)

# After editing .proto / .sql / openapi.yaml:
make proto
make sqlc
make bff-gen
make flutter-client-gen
```

---

## 12. Current status and known gaps

Working well:

- Single HTTP binary serving the full OpenAPI surface to Flutter clients.
- Two-phase settlement with conflict resolution, auto-sweep, ceiling recovery, and PaymentRequest binding.
- Cryptographic domain (Ed25519, AES-256-GCM, sealed box, canonical JSON, fuzz-tested).
- Double-entry ledger with deferred constraint validation + transactions event log.
- Transactional outbox for transfers (NATS JetStream).
- Fraud signal aggregation with exponential decay; separate transfer-scoring surface.
- Rate limiting (in-memory + Redis token bucket), structured logging, OpenTelemetry tracing, Prometheus metrics.
- Admin API + Nuxt dashboard with RBAC + audit log.

Partial / stubs:

- On-device key custody. The `HardwareSigner` interface + platform-channel scaffolding (Android/iOS) are in place; the current default is `SoftwareSigner` over `flutter_secure_storage`. StrongBox / Secure Enclave wiring is blocked on an ECDSA-P-256 protocol decision (iOS Secure Enclave doesn't offer Ed25519).
- `ATTESTATION_MODE=dev` accepts any attestation payload; production verifiers are wired but not deployed.
- Admin dashboard: auth + users + transactions + settlement + fraud + audit shipped; KYC ops, fraud ops, analytics, admin-user management UIs are tracked follow-ups.
- Edge TLS termination is the deployment's responsibility; BFF serves plain HTTP.
- `cmd/transferworker` has no NATS auth/TLS yet.

Everything here is PoC-phase software. Prod checklist before shipping: `CRYPTO_SIGNER=vault`, `ATTESTATION_MODE=production` with real verifiers, rotate all dev secrets, turn on NATS auth/TLS, terminate TLS at the edge, resolve the HSM protocol question, wire remote CI in place of the pre-commit hook.
