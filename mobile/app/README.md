# offlinepay_app

Single unified Flutter C2C app for the offline_pay QR payment system. Every user is symmetrically a sender and a receiver — there is no "merchant" build flavour.

## Quickstart

```bash
cd mobile/app
flutter pub get
flutter run
```

The app depends on two sibling path packages:

- `../packages/core` — crypto, canonical encoding, QR + NFC framing, gossip, token/request/display-card models.
- `../packages/offlinepay_api` — Dart client generated from `backend/api/openapi.yaml`.

Run `(cd ../../backend && make flutter-client-gen)` whenever the OpenAPI spec changes.

## Source layout

```
lib/
├── main.dart
├── firebase_options.dart
└── src/
    ├── app.dart                      # MaterialApp + _RootGate (routes on SessionCubit.state.gate)
    ├── theme.dart
    ├── core/
    │   ├── auth/                     # JWT parsing, refresh interceptor, token store
    │   ├── di/service_locator.dart   # get_it registrations
    │   └── http/                     # Dio stack + token plumbing
    ├── presentation/cubits/          # flutter_bloc cubits (session, app, kyc, send_money)
    ├── repositories/                 # Dio call wrappers per API group
    ├── screens/
    │   ├── auth/                     # login, signup, email_verify, forgot_password, unlock
    │   ├── send_money/               # multi-step flow: account → amount → confirm → result
    │   ├── home_screen · receive_screen · receive_nfc · activity_screen
    │   ├── wallet_screen · settings_screen · sessions_screen · kyc_submit_screen
    │   ├── tiers_screen · set_pin_screen
    ├── services/
    │   ├── local_queue.dart          # SQLite WAL journal
    │   ├── sync · claim_submitter · receive_coordinator · payment_verifier · qr_receiver
    │   ├── keystore · software_signer · signer
    │   ├── offline_auth · session_store · biometric_unlock
    │   ├── gossip_pool · gossip_uploader
    │   ├── device_registrar · push_notifications_service
    │   ├── connectivity · install_sentinel
    ├── nfc/                          # Flutter-side NFC channels + transports
    ├── widgets/                      # shared widgets
    └── util/                         # money, time, biometric, haptics, txn_id
```

## Connectivity boundary

Only these paths require the network:

- Wallet management: `fund-offline`, `move-to-main`, `refresh-ceiling`, `recover-offline-ceiling`, `top-up` (dev only).
- Settlement + reconciliation: `submit claim`, `sync`, `gossip upload`.
- Key refresh: bank pubkeys, realm key versions, server sealed-box pubkey, device-session public keys.
- Online transfers: `POST /v1/transfers`.

The **Send** and **Receive** screens work fully in airplane mode. All offline state lives in a WAL-mode SQLite queue at `<app documents>/offlinepay.db`.

Cold start without connectivity is covered by the device-session token flow described in `../../docs/OFFLINE_AUTH.md`: `SessionCubit.bootstrap()` verifies the cached DST locally against the pubkey bundle in `flutter_secure_storage`, then optionally refreshes online — a network failure during refresh does not clear the offline gate.

## Tests

```bash
flutter test
```

The widget + service suites run as part of `make check` in `backend/`. The sibling Dart primitives package (`../packages/core`) carries its own `dart test` suite including the Go-generated crosslang fixture.

## Key material

`HardwareSigner`, `SoftwareSigner`, and Android/iOS platform-channel scaffolding are in place (`lib/src/services/signer.dart`, `software_signer.dart`, `keystore.dart`). The current default is `SoftwareSigner` over `flutter_secure_storage` — which maps to Android Keystore and iOS Keychain at the OS level, but leaves the Ed25519 private key materialisable in the Dart heap during a sign operation.

Production binding to StrongBox / Secure Enclave is tracked in `../../TODO.md` A-05 and is blocked on a protocol-level ECDSA P-256 decision: iOS Secure Enclave does not support Ed25519, and Android StrongBox Ed25519 is API-31+ and vendor-dependent. Moving to P-256 is a cross-cutting change that touches every signature-verify path in Go and Dart, so it's deliberate rather than a silent upgrade.

The offline unlock PIN is Argon2id-hashed in `lib/src/services/offline_auth.dart` (19 MiB / 2 iter / 1 lane / 32-byte digest, OWASP recommended for mobile). Five failed attempts trip a 5-minute lockout that survives app restart.

## Platform scaffolding

The `android/` and `ios/` directories are created by `flutter create` on first build. `minSdkVersion = 23` is required for `flutter_secure_storage`; `NSCameraUsageDescription` and Face-ID usage descriptions must be set in `ios/Runner/Info.plist`. See `../../TODO.md` A-01 for the exact bootstrap checklist.
