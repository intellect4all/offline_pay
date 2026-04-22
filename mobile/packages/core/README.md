# offlinepay_core

Shared Dart core for offline_pay. Pure Dart (no Flutter, no platform
channels): cryptographic primitives, canonical encoder, QR framing, NFC
APDU chunking, and token/envelope models consumed by `mobile/app/`.

Byte-for-byte port of the Go reference under `backend/internal/crypto`
and `backend/pkg/qr`. Ed25519 signatures, AES-GCM, sealed-box, and QR
frames round-trip between the two implementations.

---

## Layout

```
lib/
├── offlinepay_core.dart         -- public barrel export
└── src/
    ├── canonical.dart           -- deterministic JSON encoder
    ├── tokens.dart              -- CeilingTokenPayload, PaymentPayload, GossipBlob
    ├── ed25519.dart             -- sign/verify for ceilings and payments
    ├── aes_gcm.dart             -- AES-256-GCM seal/open + frame nonce derivation
    ├── sealed_box.dart          -- libsodium crypto_box_seal (pure Dart)
    ├── realm_keyring.dart       -- versioned AES key store with overlap window
    ├── qr/
    │   └── frames.dart          -- chunk, encode, decode, Reassembler
    ├── gossip/
    │   ├── bloom.dart           -- bloom filter for seen-hash dedup
    │   ├── carry_cache.dart     -- 500-blob LRU with never-evict own-txn rule
    │   ├── payload.dart         -- GossipInnerPayload, CeilingTokenWire
    │   ├── envelope.dart        -- GossipEnvelope (payment + ceiling + blobs)
    │   ├── encode.dart          -- sealGossipBlobs helper
    │   └── wire.dart            -- realm-key seal/open to/from wire bytes
    └── transport/
        ├── transport.dart       -- PaymentSendTransport / PaymentReceiveTransport
        ├── qr_transport.dart    -- animated-QR carrier
        ├── nfc_apdu.dart        -- PUT_CHUNK APDU chunking + reassembly
        └── nfc_pull_protocol.dart -- HCE pull-protocol (SELECT + GET_CHUNK)
```

---

## Module reference

### `canonical.dart`

`canonicalize(Object?) -> Uint8List` produces deterministic JSON bytes
that match Go's `backend/internal/crypto/canonical.go` byte-for-byte:

- Object keys sorted lexicographically (by Dart string compare, which
  matches Go's byte-order for ASCII keys — all protocol keys are ASCII).
- No insignificant whitespace.
- Go `encoding/json` escape rules, including HTML-safe escapes for
  `<`, `>`, `&`, and `\u2028` / `\u2029`.
- Byte arrays: base64 (padded) via the `CanonicalBytes` wrapper or a
  `Uint8List`.
- `DateTime`: RFC3339Nano UTC, matching `time.Time.MarshalJSON` — fractional
  seconds trimmed of trailing zeros, omitted entirely when zero.

**Limitation:** non-ASCII strings are emitted as `\uXXXX` escapes while Go
emits raw UTF-8. Cross-language signatures only match for ASCII-only
signed fields. All protocol fields today are ASCII.

### `tokens.dart`

Data classes mirroring the Go domain types. `toJson()` emits the map
the canonical encoder consumes; `fromJson()` parses the wire form.

| Class                 | Fields                                                                                                              |
|-----------------------|---------------------------------------------------------------------------------------------------------------------|
| `CeilingTokenPayload` | payer_id, ceiling_amount, issued_at, expires_at, sequence_start, public_key, bank_key_id                            |
| `PaymentPayload`      | payer_id, payee_id, amount, sequence_number, remaining_ceiling, timestamp, ceiling_token_id                         |
| `PaymentToken`        | payload + payer_signature                                                                                           |
| `GossipBlob`          | transaction_hash, encrypted_blob, bank_signature, ceiling_token_hash, hop_count, blob_size                          |

All monetary amounts are kobo (integer). `validate()` enforces
non-negativity and the ordering invariants; `signCeiling` / `signPayment`
call it before signing.

### `ed25519.dart`

```dart
final keys = await generateEd25519KeyPair();
final sig = await signPayment(keys.keyPair, payload);
final ok = await verifyPayment(keys.publicKey.bytes, payload, sig);
```

`signCeiling` / `verifyCeiling` are the same for the bank-issued
ceiling token. `sign*` validates the payload before canonicalising;
`verify*` does not — callers should validate separately when the
payload is received from an untrusted source. In production the payer's
private key stays in the Android Keystore / iOS Secure Enclave; this
helper exists for tests and bank-side provisioning.

### `aes_gcm.dart`

Thin wrapper around `package:cryptography`'s AES-256-GCM:

```dart
final ct = await seal(key32, nonce12, plaintext, associatedData: aad);
final pt = await open(key32, nonce12, ct, associatedData: aad);
```

`seal` returns `ciphertext || auth_tag` — matching Go's `gcm.Seal`
output. `deriveFrameNonce(base, frameIndex)` copies a 12-byte base
nonce and overwrites the last 4 bytes with a big-endian `u32`, mirroring
`binary.BigEndian.PutUint32`.

Constants: `realmKeySize = 32`, `aesGcmNonceSize = 12`, `aesGcmTagSize = 16`.

### `sealed_box.dart`

libsodium-compatible `crypto_box_seal`:

```
ephPub, ephPriv = X25519 keypair (fresh per seal)
shared          = X25519(ephPriv, recipientPub)
subkey          = HSalsa20(shared, zeros16)
nonce24         = blake2b-24(ephPub || recipientPub)
ct              = XSalsa20-Poly1305(subkey, nonce24, plaintext)
output          = ephPub(32) || ct || tag(16)
```

X25519 shared-secret uses `package:cryptography`; Blake2b and Poly1305
come from pointycastle; Salsa20/HSalsa20 is implemented directly in
this file to match NaCl.

Use `sealAnonymous(recipientPub, plaintext)` to encrypt; use
`openAnonymous(recipientPub, recipientKeyPair, ciphertext)` to decrypt.
Only the server (gossip sink) holds the private key — carriers
propagate blobs opaquely.

### `realm_keyring.dart`

Device-side store of `(version -> 32-byte AES-256 key)` pairs. QR
frame decoders read the 1-byte `key_version` prefix and call
`keyring.keyFor(version)`; encoders always seal to `keyring.activeKey`.
A rotation window keeps one or two previous versions decrypt-capable
so in-flight QRs don't break at rotation boundaries.

### `qr/frames.dart`

Three frame kinds: `kindHeader` (0), `kindPayload` (1), `kindTrailer` (2).
`chunk(content, chunkSize, contentType)` produces `[header, payload_1..N, trailer]`.
Header and trailer both carry the SHA-256 digest of `content`.

Wire layout per frame (big-endian):

```
[kind:u8] [protocol:u16] [index:u32] [total:u32] [ct_len:u16] [ct:bytes] [payload_len:u32] [payload:bytes]
```

`Reassembler` accepts frames in any order, tolerates duplicates, and
verifies the SHA-256 digest on `assemble()`.

### `gossip/`

- **`bloom.dart`** — 8192-bit, 4-hash filter for seen-hash dedup.
- **`carry_cache.dart`** — capacity 500; oldest-first eviction skipping
  own-txn entries; `incrementHops()` drops blobs at or past
  `maxGossipHops` (3); `outgoingBundle(maxBytes)` selects the most
  recent blobs that fit under a byte budget.
- **`payload.dart`** — `GossipInnerPayload` (the sealed-box plaintext:
  ceiling + payment + sender_user_id).
- **`envelope.dart`** — `GossipEnvelope` (payment_token + optional
  ceiling + blobs[]); this is what the QR frames carry after realm-key
  encryption.
- **`encode.dart`** — `sealGossipBlobs(plaintexts, serverPub)` computes
  `transaction_hash = SHA-256(canonical(inner))` and
  `ceiling_token_hash = SHA-256(canonical(ceiling.payload))`, then
  sealed-boxes each inner to the server.
- **`wire.dart`** — realm-key seal/open of the envelope:

```
[key_version:u8] [base_nonce:12] [AES-256-GCM(realm_key, base_nonce, canonical(envelope), aad=[key_version])]
```

`chunkEnvelopeFrames(wire)` passes through to `qr/frames.dart`;
`openEnvelopeFromWire(wire, keyForVersion)` slices off the 13-byte header,
looks up the realm key, decrypts, and parses the JSON back into a
`GossipEnvelope`. `UnknownKeyVersionError` is thrown when the keyring
doesn't carry the advertised version — the UI should prompt the user to
reconnect and refresh.

### `transport/`

Channel abstraction (`PaymentSendTransport` / `PaymentReceiveTransport`)
with two implementations today: animated QR (`qr_transport.dart`) and
NFC (`nfc_apdu.dart` + `nfc_pull_protocol.dart`).

**NFC pull protocol (HCE, ISO-DEP):**

1. Reader sends `SELECT(AID)` with AID `F0 4F 46 4C 50 41 59 01`.
2. HCE replies `90 00`.
3. Reader sends `GET_CHUNK(idx)` = `80 A0 <idx> 00 00`.
4. HCE replies `<total:u8> <chunk_data:1..240> 90 00`.
5. Reader discovers `total` from the first response, then drains the rest.

The payer stages chunk responses at payment-prep time via
`stageChunkResponses(sealedWire)`. Reassembly happens on the reader
side using `NfcReassembler`.

NFC carries the same sealed wire bytes as QR. Link-level CRC + AES-GCM
tag cover integrity, so the SHA-256 framing is not re-applied.

---

## Usage

### Payer — seal and transmit

```dart
final envelope = GossipEnvelope(
  paymentToken: PaymentToken(payload: payload, payerSignature: sig),
  ceiling: EnvelopeCeiling(id: ceilingId, payload: ceilingPayload, bankSignature: bankSig),
  blobs: carryCache.outgoingBundle(maxBytes: 48 * 1024),
);
final sealed = await sealEnvelopeToWire(
  envelope: envelope,
  realmKey: keyring.activeKey,
  keyVersion: keyring.activeVersion,
);
final frames = chunkEnvelopeFrames(sealed.wireBytes); // for QR
```

### Merchant — receive and verify

```dart
final reassembler = Reassembler();
for (final frameBytes in scannedFrames) {
  reassembler.accept(decodeFrame(frameBytes));
  if (reassembler.complete()) break;
}
final opened = await openEnvelopeFromWire(
  reassembler.assemble().content,
  (v) => keyring.keyFor(v),
);
final ok = await verifyPayment(
  opened.envelope.ceiling!.payload.payerPublicKey,
  opened.envelope.paymentToken.payload,
  opened.envelope.paymentToken.payerSignature,
);
```

---

## Testing

```
dart pub get
dart test
```

The suite loads `test/fixtures/crosslang.json` produced by the Go side.
Regenerate after any canonical-encoder or schema change:

```
cd ../../../backend
go test -tags=fixtures ./internal/crypto/... -run TestEmitCrossLangFixture
```

The fixture contains a canonical JSON sample, signed ceiling and
payment payloads with key material, an AES-GCM sample, a chunked QR
frame sequence, and sealed-gossip inner payloads.

---

## Known limitations

- The sealed-box implementation is hand-rolled Salsa20 / HSalsa20; the
  cross-language fixture is the only known-answer check. Consider adding
  NaCl/libsodium KATs for HSalsa20 and Salsa20 directly.
- Canonical encoder sorts map keys by UTF-8 byte order and emits raw
  UTF-8 for non-ASCII code points, matching Go's `encoding/json`. This
  is covered by the `canonical` tests; add explicit non-ASCII KATs when
  the protocol starts carrying localised fields.

## Scope

Pure Dart only. Keystore bridges, gRPC clients, and UI live in the
Flutter app under `mobile/app/` (Phase 8+).
