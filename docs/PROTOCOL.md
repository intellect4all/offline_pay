# OfflinePay Protocol

This document specifies the cryptographic and wire protocols used by OfflinePay against the current implementation. Every normative claim cites a file path so a reviewer can implement a byte-compatible client from source. Where the design has evolved (PaymentRequest binding, DisplayCard identity credentials, ceiling recovery) the migration number is noted so you can read the rationale in the schema comments.

## 1. Identities and keys

| Key | Purpose | Owner | Primitive |
|-----|---------|-------|-----------|
| Bank signing key | sign `CeilingTokenPayload` and `DisplayCardPayload` | server (`bank_signing_keys` or Vault) | Ed25519 |
| Payer key | sign `PaymentPayload` | device HSM (fallback: `flutter_secure_storage`) | Ed25519 |
| Receiver device key | sign `PaymentRequestPayload` | receiver device (same HSM, same keypair) | Ed25519 |
| Realm key | AES-256-GCM of QR/NFC frame payloads | all registered devices | AES-256 |
| Server sealed-box key | decrypt gossip blobs | BFF process | X25519 (Curve25519) |
| BFF device-session key | sign the cold-start `DST` token (see `OFFLINE_AUTH.md`) | BFF process | Ed25519 |
| Device identity key | future attestation binding | device HSM | Ed25519 |

Bank keys carry a `key_id`; devices cache every active and within-overlap public key and match by id at verify time. The same active bank key that signs ceiling tokens also signs `DisplayCard`s (`backend/internal/service/identity/service.go`) — this keeps the client trust anchor to a single set of pubkeys.

Realm keys carry an integer `version` negotiated via `GET /v1/keys/realm/active` (and one-at-a-time via `GET /v1/keys/realm/{version}`).

Payer keys are tracked in the `signing_keys` table (migration `0003_signing_keys`). Rotation inserts a new active row, flips the prior one to `active=false, rotated_at=now()`. Historic ceilings keep verifying because every ceiling token snapshots the payer pubkey bytes into `ceiling_tokens.payer_pubkey` at issuance — they are not FK'd back to the key row.

## 2. Canonical encoding

All bytes that are signed, MAC-ed, or sealed are first passed through the canonical JSON encoder at `backend/internal/crypto/canonical.go`. Rules:

- Object keys sorted lexicographically by UTF-8 byte order.
- No insignificant whitespace.
- `[]byte` fields emitted as standard base64 (with padding) via `encoding/json` defaults.
- `time.Time` emitted as RFC3339Nano via `encoding/json` defaults.
- `json.Number` preserved verbatim (no float coercion).

The Dart port at `mobile/packages/core/lib/src/canonical.dart` matches byte-for-byte; `mobile/packages/core/test/fixtures/crosslang.json` pins cross-language equivalence. The cross-lang fuzz fixture covers canonical JSON, Ed25519 signatures over all four payload types (ceiling, payment, request, display card), AES-GCM seals, sealed-box round-trips, and chunked QR frames.

## 3. Token formats

### 3.1 `CeilingTokenPayload`

Source: `backend/internal/domain/ceiling.go`.

| field | type | notes |
|-------|------|-------|
| `payer_id` | string | user id (ULID). |
| `ceiling_amount` | int64 | kobo, > 0. |
| `issued_at` | time | UTC. |
| `expires_at` | time | UTC, must be > `issued_at`. |
| `sequence_start` | int64 | monotonic floor for this ceiling; current impl issues at `0`. |
| `public_key` | bytes | 32-byte Ed25519 payer pubkey, snapshotted from the active `signing_keys` row. |
| `bank_key_id` | string | selects verifier. |

Validation rejects zero amounts, missing fields, and expiry-before-issuance. The bank signs `Canonicalize(payload)` via `crypto.SignCeiling` (or `SignCeilingWithSigner` when a KMS signer is wired).

### 3.2 `DisplayCardPayload` *(new — migration 0024 era)*

Source: `backend/internal/domain/display_card.go`.

| field | type | notes |
|-------|------|-------|
| `user_id` | string | |
| `display_name` | string | human-readable name shown to payers. |
| `account_number` | string | 10-digit public handle. |
| `issued_at` | time | UTC. |
| `bank_key_id` | string | selects verifier. |

Issued by `identity.Service.IssueDisplayCard`. Signed by the active bank key (reuses the ceiling trust anchor — no new pubkey to cache). Cards are stateless — regenerated on demand via `GET /v1/identity/display-card` and embedded by the receiver in every `PaymentRequest`. The payer verifies `ServerSignature` against the cached bank pubkey and thereby trusts the displayed name.

### 3.3 `PaymentRequestPayload` *(new — migration 0024)*

Source: `backend/internal/domain/payment_request.go`.

| field | type | notes |
|-------|------|-------|
| `receiver_id` | string | must equal `receiver_display_card.user_id`. |
| `receiver_display_card` | DisplayCard | bank-signed identity credential (§3.2). |
| `amount` | int64 | kobo, ≥ 0. `0` is the **unbound** sentinel: the payer picks the amount (the P2P fallback). |
| `session_nonce` | bytes | 16 random bytes, single-use per receiver. |
| `issued_at` / `expires_at` | time | UTC; `expires_at > issued_at`. |
| `receiver_device_pubkey` | bytes | Ed25519; same key as the receiver's payer key. |

The receiver signs `Canonicalize(payload)` with their device key (`crypto.SignRequest`). The receiver's device displays the request on its QR/NFC output; the payer scans and counter-signs a `PaymentToken` (§3.4) referencing the same `session_nonce`.

`session_nonce` replay is closed off by `UNIQUE (payee_user_id, session_nonce)` on `payment_tokens` (migration `0024`) — one PR can back exactly one accepted payment.

### 3.4 `PaymentPayload`

Source: `backend/internal/domain/payment.go`.

| field | type | notes |
|-------|------|-------|
| `payer_id` | string | must differ from `payee_id`. |
| `payee_id` | string | |
| `amount` | int64 | kobo, > 0. |
| `sequence_number` | int64 | > 0, monotonic per `ceiling_token_id`; enforced at DB by `UNIQUE (payer_user_id, sequence_number)` (migration `0010`). |
| `remaining_ceiling` | int64 | ≥ 0 after this txn. |
| `timestamp` | time | device clock, audit-only — **never** used for ordering. |
| `ceiling_token_id` | string | references the signed ceiling. |
| `session_nonce` | bytes | 16B copied from the PR the payer is counter-signing. |
| `request_hash` | bytes | `SHA-256(canonical(PaymentRequest))`. |

Payer signs `Canonicalize(payload)` with the device key (`crypto.SignPayment`). The on-wire `PaymentToken` is the payload fields plus `payer_signature`.

### 3.5 Ed25519 signing helpers

`backend/internal/crypto/ed25519.go` exposes matched pairs for every payload type:

- `SignCeiling` / `VerifyCeiling`
- `SignPayment` / `VerifyPayment`
- `SignRequest` / `VerifyRequest`
- `SignDisplayCard` / `VerifyDisplayCard`

Every signer has a `*WithSigner` variant that delegates to a `CeilingSigner` (the Vault transit wrapper in `internal/crypto/kms/`). `CRYPTO_SIGNER=vault` flips the bank key over to Vault; everything else stays local-signing.

## 4. Realm-layer encryption (AES-256-GCM)

Source: `backend/internal/crypto/aes_gcm.go`.

- Key size: 32 bytes (`RealmKeySize`).
- Nonce size: 12 bytes (`NonceSize`).
- `Seal(key, nonce, plaintext, associatedData)` / `Open(...)` wrap `crypto/cipher`'s GCM directly; associated data is authenticated but not encrypted.
- `NewRandomBaseNonce()` returns a 12-byte buffer with the first 8 bytes random and the last 4 bytes zeroed. Per-frame nonces are derived by `DeriveFrameNonce(base, frameIndex)`, which copies `base` and overwrites the last 4 bytes with `frameIndex` as big-endian `uint32`.

Every frame in a single QR / NFC stream therefore has a unique nonce under one realm key, with no coordination between producer and consumer.

Key versions and rotation: the `realm_keys` table (migration `0008`) carries one row per version. `GET /v1/keys/realm/active` returns every active+overlap version; the Dart `RealmKeyring` (`mobile/packages/core/lib/src/realm_keyring.dart`) caches them and falls back through on decrypt. The 1-byte `key_version` prefix in the capsule tells the scanner which key to use.

## 5. Sealed box (libsodium-compatible)

Source: `backend/internal/crypto/sealed_box.go`, ported at `mobile/packages/core/lib/src/sealed_box.dart`.

- Keys: X25519 (Curve25519) — 32 bytes each.
- Overhead: 32 (ephemeral pubkey) + 16 (Poly1305 tag) = 48 bytes.
- `SealAnonymous(recipientPub, plaintext)`:
  1. Generate ephemeral X25519 pair `(eph_pub, eph_priv)`.
  2. Derive nonce = `blake2b-24(eph_pub || recipient_pub)`.
  3. `out = eph_pub || NaCl_box.Seal(plaintext, nonce, recipient_pub, eph_priv)`.
  4. Discard `eph_priv`.
- `OpenAnonymous(recipientPub, recipientPriv, ciphertext)` reverses this.

This matches libsodium `crypto_box_seal` byte-for-byte. Server-side rotation: `SERVER_SEALED_BOX_PRIVKEY` is the current decrypt key; `SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS` holds retired keys for the overlap window (comma-separated). The gossip service tries each key in order on open.

## 6. Animated QR wire format

Source: `backend/pkg/qr/frames.go`.

### 6.1 Frame structure

```
kind        u8      (0=header, 1=payload, 2=trailer)
protocol    u16 BE  (current: 1)
index       u32 BE
total       u32 BE
ct_len      u16 BE  (content-type length, 0 on non-header)
content_type[ct_len] bytes
payload_len u32 BE
payload     [payload_len] bytes
```

Encoded by `Encode(Frame)`; decoded by `Decode`.

### 6.2 Header / trailer

- **Header** (`KindHeader`, index `0`): carries `protocol`, `total`, `content_type`, and `payload = SHA-256(plaintext-payload-concat)`.
- **Payload** frames 1..N-2: each carries one chunk of at most `DefaultChunkSize = 2048` bytes.
- **Trailer** (`KindTrailer`, index `total-1`): carries the same SHA-256 again.

`Reassembler.Accept`/`Complete`/`Missing`/`Assemble` is order-independent and tolerates duplicate frames; mismatch returns `ErrChecksumMismatch`.

### 6.3 Per-frame encryption

Each payload chunk is independently AES-GCM sealed with `DeriveFrameNonce(base, frame.index)`. The 1-byte `key_version` travels unencrypted in the capsule header so the scanner can pick the right realm key. Final on-wire capsule:

```
[key_version: 1B][nonce: 12B][AES-GCM ciphertext][GCM tag: 16B]
```

The Dart capsule builder is `mobile/packages/core/lib/src/gossip/wire.dart`.

## 7. NFC wire format *(new since prior revision)*

Source: `backend/pkg/qr/frames.go` (shared framing), `mobile/packages/core/lib/src/transport/nfc_apdu.dart`, `nfc_pull_protocol.dart`.

NFC tap carries the exact same sealed wire bytes as QR, wrapped in a simple HCE (Host Card Emulation) ISO-DEP pull protocol:

1. Reader → HCE: `SELECT(AID)` with AID `F0 4F 46 4C 50 41 59 01`.
2. HCE → Reader: `90 00`.
3. Reader → HCE: `GET_CHUNK(idx)` = `80 A0 <idx_hi> <idx_lo> 00`.
4. HCE → Reader: `<total:u8> <chunk_data:1..240> 90 00`.
5. Reader discovers `total` from the first response and drains the rest.

The payer stages chunk responses at payment-prep time via `stageChunkResponses(sealedWire)`. `NfcReassembler` reassembles on the reader side. Since the NFC link already carries CRC and AES-GCM already authenticates the payload, the SHA-256 header/trailer framing used for QR is skipped on NFC.

## 8. Gossip inner payload

Source: `backend/internal/service/gossip/service.go`.

A gossip blob carries a full claim so any device can hand it to the server.

```go
type CeilingTokenWire struct {
    ID            string                       `json:"id"`
    Payload       domain.CeilingTokenPayload   `json:"payload"`
    BankSignature []byte                       `json:"bank_signature"`
}
type WireInnerPayload struct {
    Ceiling      CeilingTokenWire    `json:"ceiling"`
    Payment      domain.PaymentToken `json:"payment"`
    Request      domain.PaymentRequest `json:"request"`         // matches the new Phase-4a contract
    SenderUserID string                `json:"sender_user_id"`  // whoever originally scanned
}
```

The canonical bytes go into `SealAnonymous(serverPub, ...)`. On upload, `gossip.Upload` validates the outer `GossipBlob` (hop limit, required fields), opens the sealed box, decodes the inner payload, rebuilds a `ClaimItem` (now including the PR), and routes it into `settlement.SubmitClaim`. Dedupe by `(payer_id, sequence_number)` absorbs duplicates — gossip is the same code path as direct submission.

Rules (`backend/internal/domain/gossip.go`): `MaxGossipHops = 3`, carry cap 500, never-evict-own. The Dart `CarryCache` in `mobile/packages/core/lib/src/gossip/carry_cache.dart` enforces the same rules on-device.

## 9. Settlement flow

### 9.1 Phase 4a — `SubmitClaim`

`backend/internal/service/settlement/service.go`.

For each `ClaimItem` (a tuple of `PaymentToken` + backing `CeilingToken` + the `PaymentRequest` it counter-signs):

1. **Structural guards.** `p.PayerID != p.PayeeID` (self-pay); `p.PayerID == c.PayerID`; `p.CeilingTokenID == c.ID`; `submitterUserID ∈ {p.PayerID, p.PayeeID}` — random third parties cannot submit somebody else's claim even if they've got the blob; `req.ReceiverID == p.PayeeID`; `req.ReceiverDisplayCard.UserID == req.ReceiverID`.
2. **Bank signature on ceiling.** Resolve the key by `c.BankKeyID`, call `crypto.VerifyCeiling`. Failure → `FraudSignatureInvalid` (severity HIGH), reject.
3. **Payer signature on payment.** `crypto.VerifyPayment` against the payer pubkey embedded in the ceiling. Failure → `FraudSignatureInvalid` (HIGH), reject.
4. **DisplayCard server signature.** `crypto.VerifyDisplayCard` against the (usually same) bank key id carried on the card. Reject on failure.
5. **Receiver signature on PaymentRequest.** `crypto.VerifyRequest` against `req.ReceiverDevicePubkey`. Reject on failure.
6. **PaymentRequest binding.** `session_nonce` equality between token and request; `request_hash` recomputed from `crypto.HashRequest` and compared byte-for-byte; `amount` equality unless the PR is unbound (`Amount == 0`); expiry `now ≤ req.ExpiresAt + RequestGrace`. Any mismatch → reject.
7. **Sequence + expiry.** `p.SequenceNumber > c.SequenceStart` (otherwise `FraudSequenceAnomaly` MEDIUM + reject); `now ≤ c.ExpiresAt + ClockGrace` (default 30 min; reject on fail).
8. **Idempotent dedupe** by `(payer_user_id, sequence_number)`. If a row already exists, return its current status unchanged (no re-post).
9. **Ceiling liveness.** The ceiling must be `ACTIVE` (new-issue) or — if it already moved to `RECOVERY_PENDING` or a terminal state — reject. Note that the dedupe at step 8 runs *before* this check so a retry of an already-accepted claim succeeds idempotently even after the ceiling later transitions.
10. **Accept.** In a sub-tx: `INSERT payment_tokens` (`status=PENDING`, populated with `session_nonce`, `request_hash`, `request_amount_kobo`, `submitted_by_user_id`), write a `transactions` row for the claim (status `PENDING`), post balanced ledger legs `DEBIT suspense / CREDIT receiving_pending`, stamp `submitted_at` and `settlement_batch_id`.

Per-item failures surface in `BatchReceipt.results[]`; infrastructure errors abort the batch and return it with `BatchFailed`.

### 9.2 Phase 4b — `FinalizeForPayer`

Single outer transaction:

1. `ListPendingForPayer(payerUserID)`, sorted ASC by `sequence_number` (defensive re-sort in-memory).
2. Load the ceiling (via the first pending payment's `ceiling_token_id`); track `remaining = ceiling.CeilingAmount`.
3. For each txn in sequence order:
   - If `remaining <= 0` → `settled = 0`, state `PARTIALLY_SETTLED`, reason `ceiling exhausted`.
   - Else if `amount <= remaining` → `settled = amount`; state `SETTLED`.
   - Else (partial) → `settled = remaining`; state `PARTIALLY_SETTLED`; reason `ceiling short by N kobo`.
   - Post ledger legs against the same `txn_id` that was created as the Phase-4a anchor:
     ```
     settled>0:
       DEBIT  lien_holding_A            settled    (4b lien release)
       CREDIT suspense                  settled    (4b suspense repay)
       DEBIT  receiving_pending_B       settled    (4b pending drain)
       CREDIT main_B                    settled    (4b main credit — funds spendable immediately)
     unsettled = amount-settled > 0:
       DEBIT  receiving_pending_B       unsettled  (4b unsettled reverse)
       CREDIT suspense                  unsettled  (4b suspense reverse)
     ```
4. If `remaining` lands at `0`, transition the ceiling to `EXHAUSTED`.

Both 4a and 4b produce double-entry–balanced postings and the system-wide `suspense` returns to 0 once all pending claims for a ceiling reach a terminal state.

### 9.3 `AutoSettleSweep`

Cron entrypoint (`service.go:AutoSettleSweep`, kicked every 15 min from `cmd/bff/main.go`) that finds payers whose oldest `PENDING` row is older than `AutoSettleTimeout` (default 72h) and finalises each. Safe because funds were already held at issuance.

### 9.4 Ceiling recovery

`wallet.RecoverOfflineCeiling(userID)` (migration `0022`) marks the active ceiling `RECOVERY_PENDING` and stamps `release_after = expires_at + AutoSettleTimeout + ClockGrace`. The device stops signing new payments but merchants carrying already-signed tokens can still submit (step 9 above uses the `(payer, sequence)` dedupe to admit them). Once `release_after` elapses, `wallet.ReleaseOnExpiry` drains the remaining lien to `main`, writes an `OFFLINE_RECOVERY_RELEASE` transaction, and flips the ceiling to `REVOKED`. Index `idx_ceiling_recovery_sweep` (`status = RECOVERY_PENDING`, partial) keeps the sweep cheap.

## 10. Conflict resolution

- **Deterministic order:** `sequence_number`, never timestamp.
- **Ceiling exhaustion** is handled by the running `remaining` counter; the first over-the-line payment becomes `PARTIALLY_SETTLED` with the exact shortfall; subsequent payments become `PARTIALLY_SETTLED` with `settled_amount = 0`.
- **Self-pay** rejected at submit (`ErrSelfPay`) *and* at the DB (`CHECK (payer_user_id <> payee_user_id)`, migration `0010`).
- **Replay:** `UNIQUE (payer_user_id, sequence_number)` (token level) and `UNIQUE (payee_user_id, session_nonce)` (PR level, migration `0024`) together make each PaymentRequest single-use and each payment sequence single-use.
- **Expired ceilings:** `now > expires_at + ClockGrace`.
- **Expired requests:** `now > req.ExpiresAt + RequestGrace` — independent of ceiling TTL. A PR is a short-lived contract.

## 11. Key rotation

- **Bank signing key.** `bank_signing_keys` table (migration `0007`) carries `(key_id, pubkey, privkey_enc, active_from, retired_at)`. New keys are issued before retirement; both public keys are returned to clients via `POST /v1/keys/bank-public-keys`. Settlement resolves the verifier by `ceiling.bank_key_id` (and `display_card.bank_key_id`), so overlap is inherent. `CRYPTO_SIGNER=vault` delegates signing to Vault transit and the `privkey_enc` column becomes a handle.
- **Realm key.** `realm_keys` table (migration `0008`). The 1-byte `key_version` in every QR/NFC capsule selects the scanner's decryption key. Rotation: publish a new version via `opsctl rotate-realm-key`; clients switch on next sync; the old key remains valid until its `retired_at` passes.
- **Sealed-box key.** X25519 keypair distributed via `GET /v1/keys/sealed-box-pubkey`. To rotate: `opsctl rotate-sealedbox-key` prints the new env block; promote to `SERVER_SEALED_BOX_PRIVKEY` and append the old one to `SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS`. Keep the overlap one ceiling-TTL plus `AutoSettleTimeout` (default 24h+72h = 96h).
- **Device-session key.** `opsctl gen-device-session-key` — see `docs/OFFLINE_AUTH.md` §Operations.

All four rotations are supported by the schema and runtime today.
