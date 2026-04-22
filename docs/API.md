# HTTP API Reference

The single source of truth is `backend/api/openapi.yaml` (OpenAPI 3.1, ~3k lines). The BFF embeds it and serves:

- `GET /openapi.yaml` — raw spec
- `GET /docs` — Swagger UI

For machine-readable schemas, always read the YAML. This page is a narrative orientation: the route groups, how auth works, the idempotency guarantees, and which service each group dispatches to.

The Dart client at `mobile/packages/offlinepay_api/` is regenerated from the same spec via `make flutter-client-gen`.

## Conventions

- **Transport.** HTTPS, JSON bodies. HTTP/1.1.
- **Auth.** Short-lived JWT access tokens (HMAC-SHA256, `aud=offlinepay-user`) in `Authorization: Bearer <jwt>`. Issued by `/v1/auth/signup` and `/v1/auth/login`; refreshed via `/v1/auth/refresh`; revocation by `/v1/auth/logout`. The BFF validates every JWT itself — there is no gateway layer.
- **Device-session auth.** A second token — the `DST`, signed by a server Ed25519 key — powers the cold-start "unlock the app without internet" flow. Minted by `POST /v1/auth/device-session` after a successful access-token refresh; verified *on-device* against the pubkey served by `GET /v1/auth/device-session/public-keys`. See `docs/OFFLINE_AUTH.md` for the full model.
- **Keyless routes.** `/health`, `/docs`, `/openapi.yaml`, signup/login/refresh/logout, forgot-password, device recovery, bank/realm/sealed-box public-key lookups, `GET /v1/auth/device-session/public-keys`, and `/demo/*` (dev only).
- **Idempotency.** `POST /v1/settlement/claims` carries a `client_batch_id`. Payment-level dedupe is automatic via the `(payer_user_id, sequence_number)` unique index plus `(payee_user_id, session_nonce)` for the PaymentRequest side; uploading the same tokens twice is a no-op. `POST /v1/wallet/fund-offline` and `/v1/wallet/refresh-ceiling` are not idempotent — retrying fails with 409 via the "one live ceiling per user" rule (broadened in migration `0023` to cover both `ACTIVE` and `RECOVERY_PENDING`).
- **Money.** All `*_kobo` fields are `int64` kobo. Never fractional.
- **Errors.** JSON `{ "code": "...", "message": "..." }`. Validation → 400, bad credentials → 401, policy → 402/403, conflict → 409, rate limit → 429.

---

## Auth (`/v1/auth/*`)

Backed by `internal/service/userauth`.

| Route | Purpose |
|---|---|
| `POST /v1/auth/signup` | Phone + password + profile; lands at KYC tier `TIER_1`; dispatches email-verify OTP. |
| `POST /v1/auth/login` | Phone + password → access + refresh tokens. |
| `POST /v1/auth/refresh` | Exchange refresh token for a new access token. |
| `POST /v1/auth/logout` | Revoke a refresh token. |
| `POST /v1/auth/email/verify/request` | Request email-verification OTP (auth required). |
| `POST /v1/auth/email/verify/confirm` | Confirm the OTP. |
| `POST /v1/auth/forgot-password/request` | Dispatch password-reset OTP (keyless). |
| `POST /v1/auth/forgot-password/reset` | Reset password using OTP. |
| `POST /v1/auth/pin` | Set / change the transaction PIN. Separate `user_pins` table with bcrypt hash + attempt counter + 15-min lockout (migration `0002`). |
| `GET  /v1/auth/sessions` | List the authenticated user's active refresh sessions. |
| `POST /v1/auth/sessions/{id}/revoke` | Revoke a single session by id. |
| `POST /v1/auth/sessions/revoke-all-others` | Keep this session, revoke everything else. |
| `POST /v1/auth/device-session` | Mint a server-signed device-session token (DST) for offline cold start. |
| `GET  /v1/auth/device-session/public-keys` | Fetch the trust anchors (keyless; rotation-ready). |

Login, signup, and refresh responses may also surface a freshly-issued DisplayCard inline so the app can skip a second round-trip — treat the field as optional and fall back to `GET /v1/identity/display-card`.

## Identity (`/v1/identity/*`, `/v1/me`, `/v1/accounts/*`, `/v1/kyc/*`)

| Route | Purpose |
|---|---|
| `GET  /v1/me` | Current user profile + KYC tier. |
| `GET  /v1/accounts/resolve/{accountNumber}` | Resolve a 10-digit account number → masked name (for pre-transfer confirmation). |
| `GET  /v1/identity/display-card` | Fetch the caller's current bank-signed DisplayCard (§3.2 of `docs/PROTOCOL.md`). Receivers embed this in every PaymentRequest they publish; payers verify the signature against cached bank pubkeys. |
| `POST /v1/kyc/submit` | Submit a BVN / NIN document. |
| `GET  /v1/kyc/submissions` | List submitted documents + statuses. |
| `GET  /v1/kyc/hint` | Hint at what the user needs to upload next. |

## Transfers (`/v1/transfers/*`)

Online P2P transfers via the transactional outbox. Backed by `internal/service/transfer`; settlement runs in `cmd/transferworker`.

| Route | Purpose |
|---|---|
| `POST /v1/transfers` | Initiate an online transfer. Requires `pin`. Returns `PENDING`; settled asynchronously. |
| `GET  /v1/transfers` | Paginated transfer history (both sides). |
| `GET  /v1/transfers/{id}` | Single transfer by id. |

Error codes worth knowing: `self_transfer`, `receiver_not_found`, `kyc_tier_blocked`, `exceeds_single_limit`, `exceeds_daily_limit`, `fraud_block`, `pin_bad`, `pin_locked`, `pin_not_set`.

## Wallet (`/v1/wallet/*`)

Offline-wallet lifecycle. Dispatches to the in-process `wallet.Service`.

| Route | Purpose |
|---|---|
| `POST /v1/wallet/fund-offline` | Debit main, place a lien, mint a bank-signed `CeilingToken`. Fails with 409 if a live ceiling already exists (ACTIVE or RECOVERY_PENDING). |
| `GET  /v1/wallet/balances` | `main`, `lien_holding`, `receiving_pending` balances + `as_of` timestamp. (There is no `offline` or `receiving_available` account — see `docs/ARCHITECTURE.md`.) |
| `GET  /v1/wallet/ceiling/current` | Return the caller's active/recovery-pending ceiling token if any (so devices can bootstrap without a full sync). |
| `POST /v1/wallet/move-to-main` | Revoke the active ceiling and release the lien back to `main`. Fails with 409 if in-flight claims exist (`ErrUnsettledClaims`). |
| `POST /v1/wallet/refresh-ceiling` | Atomic `MoveToMain` + `FundOffline`. Same error set as `FundOffline` minus "already exists". |
| `POST /v1/wallet/recover-offline-ceiling` | Move the active ceiling into `RECOVERY_PENDING` so the sweep can eventually release the lien after `expires_at + AutoSettleTimeout + ClockGrace`. Used when the user has lost the device holding the ceiling's private key. |
| `POST /v1/wallet/top-up` | **Dev only.** Credits `main` by an amount; gated by `BFF_ENABLE_DEV_TOPUP`. |

## Settlement (`/v1/settlement/*`)

Two-phase settlement + gossip. Dispatches to `settlement.Service`, `reconciliation.Service`, and `gossip.Service`.

### `POST /v1/settlement/claims` (Phase 4a)

Either the payer or the payee device submits a batch of scanned payment tokens plus the ceilings that back them *and* the PaymentRequests each token counter-signs.

Body:

```json
{
  "client_batch_id": "<ulid>",
  "tokens":   [PaymentTokenInput,   …],
  "ceilings": [CeilingTokenInput,   …],
  "requests": [PaymentRequestInput, …]
}
```

`tokens`, `ceilings`, and `requests` are matched internally — every token must have one ceiling and one PR. Tokens whose `session_nonce` doesn't match a request in the batch are rejected.

Response: `BatchReceipt` with a `results[]` entry per token:

| `status` | Meaning |
|---|---|
| `PENDING` | accepted, awaiting Phase 4b |
| `REJECTED` | `reason` populated — see `internal/service/settlement/service.go` for the full set (self-pay, bad ceiling/payer/receiver/display-card signature, PR hash/nonce/amount mismatch, PR expired, sequence ≤ start, ceiling mismatch or terminal, submitter-not-party). |
| `SETTLED` / `PARTIALLY_SETTLED` | same `(payer, sequence)` already finalised (idempotent replay). |

Optional header: `X-Submitter-Country` (ISO-3166 alpha-2). Fed into the fraud detector's geographic-anomaly signal.

### `GET /v1/settlement/claims/{batchId}`

Re-fetch a previously-issued batch receipt. Returns 404 if the id is unknown.

### `POST /v1/settlement/sync`

Unified C2C reconciliation — returns both payer-side and receiver-side settled transactions in one call. Disputed txn ids are recorded as `FraudGeographicAnomaly` signals.

Body:

```json
{
  "since": "2026-04-01T00:00:00Z",   // optional; omit for "all"
  "disputed_transaction_ids": [],
  "finalize": true                     // triggers FinalizeForPayer(user)
}
```

Response includes `payer_side`, `receiver_side`, `synced_at`, and a `finalized_count` for payer-side closures triggered by this call.

### `POST /v1/settlement/gossip`

Upload opaque sealed-box blobs carried on-device. Each blob is decrypted with the active server X25519 private key (falling back through `SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS`), validated (`domain.MaxGossipHops = 3`, required fields), and routed into `settlement.SubmitClaim`. Deduplication rides the same `(payer, sequence)` and `(payee, session_nonce)` indexes. One bad blob does not poison the batch.

Response: `{ accepted, duplicates, invalid }`.

## Keys (`/v1/keys/*`)

Dispatches to the in-process `KeysServer` (`internal/transport/grpc/server/keys_server.go`).

| Route | Auth | Purpose |
|---|---|---|
| `POST /v1/keys/bank-public-keys` | keyless | Fetch bank Ed25519 pubkeys by id, or all active if `key_ids` is empty. |
| `GET  /v1/keys/realm/{version}` | keyless (device_id query param required) | AES-256 realm key by version. `version=0` resolves to active. |
| `GET  /v1/keys/realm/active` | JWT | Every realm-key version still inside its overlap window, newest first. |
| `GET  /v1/keys/sealed-box-pubkey` | keyless | Backend's X25519 public half for sealed-box gossip encryption. |

## Devices (`/v1/devices/*`)

Dispatches to the in-process `RegistrationServer`. Device identity is distinct from the user JWT the BFF validates; device attestation feeds fraud signals but does not gate HTTP auth.

| Route | Auth | Purpose |
|---|---|---|
| `POST /v1/devices/attestation-challenge` | JWT | Issue a server-signed nonce for the next attestation blob. |
| `POST /v1/devices` | JWT | Register a new device (attestation required in production). |
| `POST /v1/devices/{deviceId}/attest` | JWT | Refresh / re-attest an existing device. |
| `POST /v1/devices/{deviceId}/deactivate` | JWT | Self-service device deactivation. |
| `POST /v1/devices/rotate` | JWT | Replace the active device for the authenticated user. |
| `POST /v1/devices/{deviceId}/revoke` | JWT | Revoke another device on the same user (compromise response). |
| `POST /v1/devices/recover` | keyless | Recovery flow when the user has lost their last device. Gated by `RecoveryGate`. |
| `POST /v1/devices/push-token` | JWT | Register an FCM token against the caller's user. One row per token; upsert reassigns ownership. |
| `DELETE /v1/devices/push-token` | JWT | Drop a registered FCM token (logout / uninstall cleanup). |

## Demo (`/demo/*`)

Dev-only; enabled by `BFF_ENABLE_DEMO_MINT=true`. Not part of the OpenAPI spec. See `backend/internal/transport/http/bff/demo/handler.go`.

| Route | Purpose |
|---|---|
| `GET  /demo/fund` | Static HTML funding form. |
| `GET  /demo/app.js` | JS for the funding form. |
| `POST /demo/name-enquiry` | Name enquiry against the demo mint. |
| `POST /demo/fund` | Credit an account from the demo treasury (`system-mint-treasury`, pre-funded with ₦5B by migration `0021`). |

## Admin API (port `:8081`)

Served by `cmd/adminapi`, not the BFF. Listed here only because it shares the repo and the protocol.

| Route | Purpose |
|---|---|
| `POST /v1/auth/login` / `refresh` / `logout` | Email + bcrypt; separate `admin_users` + `admin_sessions` tables (migration `0014`). |
| `GET  /v1/me` | Current admin + roles. |
| `GET  /v1/overview/stats`, `.../volume` | Dashboard stats + 14-day volume sparkline. |
| `GET  /v1/users`, `.../{id}`, `.../{id}/kyc`, `.../{id}/kyc/hint` | User browsing. |
| `GET  /v1/transactions`, `.../{id}` | Business-event log from the `transactions` table (migration `0018`). |
| `GET  /v1/settlements`, `.../{id}` | Settlement batch browsing. |
| `GET  /v1/fraud` | Fraud signal + fraud score stream. |
| `GET  /v1/audit` | Audit log — SUPERADMIN only. |

RBAC: five seeded roles (`VIEWER`, `SUPPORT`, `FINANCE_OPS`, `FRAUD_OPS`, `SUPERADMIN`). Role grants live in `admin_user_roles`. Actions write to `admin_audit_log`.

## Common payloads

All core message shapes (`CeilingToken`, `PaymentToken`, `PaymentRequest`, `DisplayCard`, `GossipBlob`, `BatchReceipt`, `AccountBalance`, `SettlementResult`) are defined once in `api/openapi.yaml`. The corresponding Go protobuf messages in `backend/proto/offlinepay/v1/common.proto` are used as internal Go DTOs — there is no wire gRPC.

Key enums:

- `TransactionStatus` — `QUEUED`, `SUBMITTED`, `PENDING`, `SETTLED`, `PARTIALLY_SETTLED`, `REJECTED`, `EXPIRED`.
- `CeilingTokenStatus` — `ACTIVE`, `RECOVERY_PENDING`, `EXPIRED`, `EXHAUSTED`, `REVOKED`.
- `AccountBalanceKind` — `MAIN`, `LIEN_HOLDING`, `RECEIVING_PENDING`. (`SUSPENSE` is server-internal; `OFFLINE` and `RECEIVING_AVAILABLE` were removed.)
- `BatchReceiptStatus` — `RECEIVED`, `PROCESSING`, `COMPLETED`, `FAILED`.
