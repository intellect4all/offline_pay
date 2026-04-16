# Mobile (Flutter)

Single unified C2C app. No separate payer/merchant builds — every user is symmetrically sender and receiver; the role is per-transaction.

Structure:

- `app/` — the user-facing Flutter app (`com.intellect.offlinepay`). Screens, services, cubits, NFC channels, repositories.
- `packages/core/` — pure-Dart shared package: Ed25519 / AES-GCM / sealed box, canonical encoder, QR frame chunker, NFC APDU chunker, gossip primitives, realm keyring, token + request + display-card models.
- `packages/offlinepay_api/` — Dio-based Dart client generated from `backend/api/openapi.yaml` via `make flutter-client-gen` (runs `openapi-generator-cli dart-dio` via `npx`; Node toolchain required).

## Layout rationale

`packages/core/` is byte-for-byte compatible with `backend/internal/crypto` and `backend/pkg/qr`. The cross-language fixture (`packages/core/test/fixtures/crosslang.json`) is generated from Go and consumed by Dart — any divergence in canonical encoding or signature layout fails the Dart suite.

`packages/offlinepay_api/` is regenerated, not hand-edited. Treat its contents as build artefacts.

`app/` holds everything UI- or platform-specific: screens, services (local SQLite queue, keystore bridges, sync, receive coordinator, gossip pool, push notifications), cubits, repositories, NFC channels.

## Running locally

```bash
cd mobile/app
flutter pub get
flutter run
```

Android and iOS platform folders are expected under `app/android/` and `app/ios/`. If you're starting from a fresh checkout without them, run `flutter create --platforms=android,ios --org com.intellect.offlinepay .` once (see `../TODO.md` A-01 for the exact bootstrap steps and the StrongBox follow-up).

## Tests

```bash
cd mobile/packages/core && dart test       # crypto + framing primitives + crosslang fixture
cd mobile/app            && flutter test   # widget + service tests
```

Both suites run as part of `make check` in `backend/`.
