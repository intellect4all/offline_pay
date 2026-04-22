# Security Posture

This document restates the attack surfaces the design identified, maps each one to the code paths that defend it, and calls out the work still deferred. File references are to current paths — if the line numbers drift, the identifiers are stable.

## Threat model

### T1. Forged ceiling tokens (bank impersonation)

*Attacker goal:* mint a `CeilingToken` out of thin air to authorise offline spending that isn't backed by a lien.

**Defences implemented.**

- Ed25519 signatures over canonical-JSON `CeilingTokenPayload` (`backend/internal/crypto/ed25519.go` — `SignCeiling` / `VerifyCeiling`).
- Public-key pinning per `bank_key_id` — clients *and* the settlement re-verifier resolve keys by id via `bank_signing_keys` (migration `0007`), so a rogue key with no row cannot be trusted.
- Bank private keys never leave the server. `CRYPTO_SIGNER=local` keeps them in Postgres under `privkey_enc`; `CRYPTO_SIGNER=vault` delegates signing to HashiCorp Vault Transit and the column becomes a key handle (`backend/internal/crypto/kms/`).
- Verification is mandatory at Phase 4a even though it was also checked on the scanning device — defence-in-depth (`backend/internal/service/settlement/service.go`).

**Deferred.** HSM-backed bank private key storage for the `local` signer (today encrypted at rest in Postgres). Vault Transit is wired and production-usable; rollout is an operational task.

### T2. Forged payment tokens (payer impersonation)

*Attacker goal:* forge a `PaymentToken` signed as user A without A's private key.

**Defences implemented.**

- Ed25519 sign/verify over canonical-JSON `PaymentPayload` (`ed25519.go` — `SignPayment` / `VerifyPayment`).
- Signature mismatch → claim `REJECTED` and `FraudSignatureInvalid` signal (severity `HIGH`) recorded against the claimed payer.
- Payer public key is pinned inside the ceiling token itself (snapshotted from `signing_keys` at issuance), not looked up at verify-time. Rotating a payer's key invalidates old ceilings automatically because the bytes on the ceiling are frozen; new ceilings embed the new pubkey.
- On-device: the full `HardwareSigner` interface + `SoftwareSigner` fallback are in place (`mobile/app/lib/src/services/signer.dart`, `software_signer.dart`, `keystore.dart`). The Android/iOS platform channels exist as scaffolding; production StrongBox / Secure Enclave wiring is a tracked follow-up (see `TODO.md` A-05) and will require a protocol-level ECDSA P-256 decision because iOS Secure Enclave does not offer Ed25519.

**Deferred.** True non-exportable HSM keys on iOS/Android; today keys live in `flutter_secure_storage` with OS-managed Keystore/Keychain semantics (`SoftwareSigner`).

### T3. Double-spend / replay

*Attacker goal:* reuse `(payer, sequence_number)` against multiple receivers, or replay a single token.

**Defences implemented.**

- `UNIQUE (payer_user_id, sequence_number)` in `payment_tokens` (migration `0010`) — hard database-level replay guard, independent of application logic.
- `UNIQUE (payee_user_id, session_nonce)` in `payment_tokens` (migration `0024`) — each `PaymentRequest` can back at most one accepted payment.
- Idempotent dedupe inside `submitOne` (`backend/internal/service/settlement/service.go`) returns the existing row on re-submit.
- `FinalizeForPayer` processes pending payments strictly in `sequence_number` order; overspend past the ceiling produces `PARTIALLY_SETTLED` with exact shortfall.
- Monotonic sequence pre-registered in the `wallet.Service` issuance path; Postgres is always the source of truth.

**Deferred.** Distributed-trace correlation IDs across Redis ↔ Postgres for forensic replay.

### T4. Lien evasion (unsettled offline spend > issued ceiling)

*Attacker goal:* force the server to credit more than was held behind the ceiling.

**Defences implemented.**

- Hard lien on `lien_holding` at `FundOffline`, before the ceiling token is signed (`wallet/service.go`).
- Settled amount checked against running `remaining` in `FinalizeForPayer` — impossible to debit lien past zero because 4b builds balanced legs only for the admitted `settled` portion.
- `NightlyLedgerReconcile` (`reconciliation/service.go`) cross-checks `SettledTotalForCeiling(id) ≤ ceiling.CeilingAmount` for every ceiling ever issued. A violation is `CRITICAL`.
- `accounts_balance_nonneg` CHECK on every non-`suspense` account (migration `0005`) would trip the transaction if a service tried to drive `lien_holding`, `receiving_pending`, or `main` negative.

### T5. Traffic analysis / QR payload disclosure

*Attacker goal:* read or modify payment data in transit or at rest on-device.

**Defences implemented.**

- Layer 1: AES-256-GCM realm-key seal per frame with frame-indexed nonce derivation (`backend/internal/crypto/aes_gcm.go`). Random scanners see ciphertext.
- Layer 2: X25519 sealed-box for gossip blobs (`backend/internal/crypto/sealed_box.go`). Only the server can decrypt; carrying devices store opaque bytes.
- Frame-level SHA-256 integrity via header + trailer hashes (`backend/pkg/qr/frames.go`). Tampered frames fail reassembly.
- 1-byte `key_version` in the unencrypted capsule prefix — realm-key rotation is explicit and lossless.
- NFC path uses the same sealed wire bytes; link-level CRC + AEAD tag cover integrity, so the SHA-256 framing is skipped.

**Deferred.** Forward secrecy for blob carriage (ephemeral per-txn X25519 pairs inside the inner payload). Primitives are in place; per-txn ephemerality is a small protocol extension.

### T6. Malicious receiver (QR swap / name spoofing)

*Attacker goal:* display the wrong name, or substitute a PR that routes funds to a different account.

**Defences implemented.**

- **PaymentRequest binding (migration `0024`).** Every `PaymentToken` carries a `session_nonce` and `request_hash = SHA-256(canonical(PaymentRequest))`. The server re-computes the hash at Phase 4a and rejects any mismatch. The payer's signature is over the hash, so a swapped PR invalidates the signature.
- **DisplayCard (bank-signed).** The PR embeds the receiver's server-signed identity credential. The payer verifies `ServerSignature` against the cached bank pubkey *before signing*, binding the displayed name to the `receiver_id` the bank attests to (`backend/internal/service/identity/service.go` issues, `settlement.Service.submitOne` re-verifies).
- **Submitter gate.** Only the payer or the named payee may submit a claim; a stranger cannot upload a stolen blob on their own behalf (`ErrSubmitterNotParty`).

### T7. Account takeover via device compromise

*Attacker goal:* steal a device or its keys and drain the victim.

**Defences implemented.**

- Device attestation at registration (`POST /v1/devices` + `POST /v1/devices/{id}/attest`). `ATTESTATION_MODE=dev` accepts any blob; `production` is wired to Android Play Integrity / iOS DeviceCheck via `internal/service/registration`.
- One live ceiling per user enforced at DB (`uq_ceiling_one_live_per_user` covers both `ACTIVE` and `RECOVERY_PENDING` after migration `0023`) — bounds the exposure window of a stolen ceiling.
- Ceiling TTL (default 24h, `CEILING_TTL_HOURS`) caps worst-case loss per ceiling.
- Transaction PIN required on money-movement endpoints (`POST /v1/transfers`), guarded by the `user_pins` table's `attempts` counter + 15-min lockout (migration `0002`). A stolen JWT alone cannot drain an account.
- Offline unlock is gated by biometric or PIN (see `docs/OFFLINE_AUTH.md`). Argon2id-hashed PIN + 5-attempt / 5-min lockout on-device.
- **Ceiling recovery** flow (`POST /v1/wallet/recover-offline-ceiling`, migration `0022`): moves the active ceiling into `RECOVERY_PENDING` so already-signed merchant claims can still land, then drains the remaining lien after `expires_at + AutoSettleTimeout + ClockGrace`.
- Operator freeze procedure in `docs/RUNBOOK.md` §7.
- Fraud signal weights (`backend/internal/service/fraud/service.go`); crossing the suspended threshold clamps the ceiling cap to zero via `wallet.FundOffline`.

**Deferred.**

- StrongBox / Secure Enclave binding (tracked in `TODO.md` A-05; protocol-level ECDSA P-256 decision pending).
- Step-up auth on high-value `FundOffline` calls.
- Edge TLS termination. The PoC runs plain HTTP on the BFF port; production deployments should terminate TLS at a reverse proxy or load balancer and restrict `BFF_HTTP_ADDR` to localhost / an internal subnet.

### T8. Backoffice compromise

*Attacker goal:* use the admin dashboard to exfiltrate data or manipulate ledger state.

**Defences implemented.**

- Separate credential domain — `admin_users` / `admin_sessions` tables (migration `0014`), bcrypt passwords, optional TOTP, separate JWT signing key (`ADMIN_JWT_SECRET`).
- RBAC with five seeded roles: `VIEWER`, `SUPPORT`, `FINANCE_OPS`, `FRAUD_OPS`, `SUPERADMIN`. Role grants in `admin_user_roles`.
- Every mutating action writes to `admin_audit_log` with the actor id + IP + payload; `GET /v1/audit` is `SUPERADMIN`-only.
- Dashboard Nuxt server keeps access/refresh tokens in httpOnly cookies; no browser-side token storage.

**Deferred.** Mandatory TOTP enrollment enforcement; step-up for destructive actions (ceiling revoke, user freeze).

## Disclosure policy

*Placeholder.* Responsible-disclosure contact, PGP key, safe-harbour clause, and target response SLAs will be published before production launch. Until then, report security findings privately to the repository owner.
