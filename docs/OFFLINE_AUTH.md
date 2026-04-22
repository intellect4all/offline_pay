# Offline Authentication

> Cold-start authentication when the device has zero internet connectivity.
> Without this, "offline pay" is a misnomer: the user can't reach the
> wallet UI to spend from their already-funded offline ceiling.

## The problem

The Flutter client previously bootstrapped its session by calling
`POST /v1/auth/refresh` against the BFF. With no network, that call
times out, the cubit clears the cached session, and the user lands on
`LoginScreen` — which itself requires the network to verify a
phone+password. Result: a fully funded offline wallet sitting behind a
login wall the user can't get past.

## The model — pre-authorise auth, not just spending

We treat authentication itself like a ceiling token: pre-authorize it
online, then verify it locally while offline. Three layers, all built
from primitives that already exist in the codebase.

```
                    ┌────────────────────────────────────────┐
                    │  ONLINE LOGIN (phone + password)       │
                    │   POST /v1/auth/login                  │
                    └───────────────┬────────────────────────┘
                                    │  access JWT
                ┌───────────────────┴──────────────────┐
                │                                      │
                ▼                                      ▼
   POST /v1/devices            POST /v1/auth/device-session
   (Ed25519 keypair, attest)   ─ binds device_id, mints
                                  Ed25519-signed token
                                ─ returns server pubkey
                                       │
                                       ▼
                   ┌──────────────────────────────────┐
                   │  Cached on-device (keystore):    │
                   │   - device session token         │
                   │   - server Ed25519 pubkey        │
                   │   - Argon2id hash of unlock PIN  │
                   └──────────────────────────────────┘
                                       │
                ── cold start, no network ──
                                       │
                                       ▼
                   1. Verify token signature locally
                   2. Check device-id binding & expiry
                   3. Prompt biometric → fall back to PIN
                   4. Unlock the offline wallet UI
```

### Layer 1 — Device-bound session token

After a successful online login (or refresh), the device immediately
calls `POST /v1/auth/device-session` with the registered `device_id`.
The BFF mints an Ed25519-signed token:

```json
{
  "header": { "alg": "EdDSA", "typ": "DST", "kid": "device-session-1" },
  "claims": {
    "sub":   "u_alice",
    "acc":   "8108678294",
    "did":   "d_galaxy",
    "scope": "offline_pay",
    "iat":   1747001234,
    "exp":   1748210834,
    "aud":   "offlinepay-user",
    "sid":   "sess_01HV..."
  }
}
```

Default TTL: **14 days** (`BFF_DEVICE_SESSION_TTL_HOURS=336`). Long enough
to cover an extended outage, short enough that a stolen device gets
quietly evicted.

Token + server public key are persisted to `flutter_secure_storage`
(Android Keystore / iOS Keychain). On cold start, the device verifies
the signature locally — no connectivity required.

### Layer 2 — Local liveness factor

A valid signature only proves "this device once held a fresh access
JWT." It says nothing about *who is currently holding the phone*. So we
gate the offline-pay UI behind a second factor:

| Factor       | Stored as                                   | When used                                  |
| ------------ | ------------------------------------------- | ------------------------------------------ |
| Biometric    | OS-managed (Face ID / Touch ID / Android)   | Auto-prompted on unlock screen mount       |
| Unlock PIN   | Argon2id hash + 16-byte salt in keystore    | Manual entry; fallback when biometric fails |

The unlock PIN is **the same PIN the user already set for online
transactions** — `set_pin_screen.dart` mirrors the entered digits into
`OfflineAuthService.setPin()` after the server-side PIN is stored. One
number, two protections.

#### Lockout policy

Five consecutive failed PIN attempts → 5-minute lockout. The counter
resets on a successful unlock. Implemented entirely on-device; survives
restarts. Tunable via `OfflineAuthService(maxFailures:, lockoutWindow:)`.

### Layer 3 — Scoped offline access

The session token carries a `scope` claim. Today there's exactly one
scope: `offline_pay`. It authorises:

- ✅ View cached wallet balance and recent activity
- ✅ Generate payment QR codes (animated, encrypted)
- ✅ Scan & verify incoming QRs into the local SQLite queue
- ✅ Carry & relay gossip blobs

It explicitly **does not** authorise:

- ❌ Top-up the offline wallet (online lien required)
- ❌ Withdraw to bank
- ❌ Change password / PIN
- ❌ View full transaction history older than the local cache
- ❌ Register a new device

When the user attempts an online-only action while offline, the UI
surfaces a "needs internet" message instead of a hard lockout. If the
session token expires while still offline, the gate flips to `expired`
and we show the login screen with a "session expired — sign in to
refresh" hint.

The blast radius is bounded by the existing offline ceiling: a stolen
unlocked phone can spend only what was already lien'd at top-up time.

## Routing

`SessionCubit.state.gate` drives `_RootGate` in `app.dart`:

| `AuthGate`           | UI                                       | Reachable when                                 |
| -------------------- | ---------------------------------------- | ---------------------------------------------- |
| `unlocked`           | `_HomeShell` (wallet, send, receive...)  | Just logged in OR PIN/biometric just succeeded |
| `locked`             | `UnlockScreen`                           | Cached token verifies but liveness not proven  |
| `expired`            | `LoginScreen` ("Session expired" hint)   | Cached token failed signature/expiry check     |
| `needsOnlineLogin`   | `LoginScreen`                            | First launch on this device                    |

Crucially: routing is on `gate`, not on `signedIn`. A device with a
valid offline token but no live access JWT still reaches the wallet.

## Backend pieces

### `internal/auth/devicesession.go`

Pure crypto: `SignDeviceSession`, `ParseDeviceSession`, `Verify`. No I/O,
fully unit-tested (`devicesession_test.go`). Mirrors the existing
`auth/jwt.go` shape so the device-side parser can reuse the same JWT
splitting logic.

### `internal/service/userauth/devicesession.go`

`Service.IssueDeviceSession(ctx, userID, deviceID, sessionID, scope)`
handles the policy: device must be owned by the caller, must still be
active, scope must be `offline_pay`. Returns the signed token plus the
server pubkey the device should cache.

The signer is wired in `cmd/bff/main.go`:

```bash
# Production: persist a stable Ed25519 private key (64-byte hex).
BFF_DEVICE_SESSION_PRIVKEY=...      # hex of seed||pub
BFF_DEVICE_SESSION_KEY_ID=device-session-1
BFF_DEVICE_SESSION_TTL_HOURS=336    # 14 days

# Dev: leave unset → ephemeral keypair, regenerated on each restart.
# Tokens issued before a restart will fail to verify after.
```

### Routes (`backend/api/openapi.yaml`)

| Method | Path                                        | Auth      | Purpose                              |
| ------ | ------------------------------------------- | --------- | ------------------------------------ |
| POST   | `/v1/auth/device-session`                   | Bearer    | Mint a fresh signed token            |
| GET    | `/v1/auth/device-session/public-keys`       | none      | Fetch trust anchors (rotation-ready) |

The public-keys endpoint is intentionally unauthenticated — devices
may need it before their access JWT is fresh, and the keys are public
material anyway.

### Server pubkey rotation

Today: a single key, identified by `kid=device-session-1`, sourced from
env. Rotation lands by:

1. Adding a second env-configured signer.
2. Returning both entries from
   `Service.ListDeviceSessionPublicKeys()` with `active_from`
   timestamps.
3. The device matches `header.kid` against its cached bundle and falls
   back to the public-keys endpoint when an unknown `kid` shows up.

The `key_id` field already flows end-to-end; only the multi-key
plumbing is left for when rotation actually happens.

## Flutter pieces

### `services/offline_auth.dart`

`OfflineAuthService` owns:

- PIN management — `setPin`, `verifyPin`, `clearPin` with Argon2id
  (defaults: 19 MiB / 2 iter / 1 lane / 32-byte digest, OWASP
  recommended for mobile).
- Token cache — `cacheDeviceSession`, `readCachedSession`,
  `clearDeviceSession`.
- Gate evaluation — `evaluateGate(expectedDeviceId:)` returns one of
  `OfflineGateState.{needsOnlineLogin, locked, unlocked, expired}`
  based on cache presence, signature validity, expiry, and
  device-id binding.

### `services/biometric_unlock.dart`

Thin `local_auth` wrapper. `isAvailable()` short-circuits on web /
desktop / not-enrolled; `authenticate()` returns true on a successful
prompt, false on cancel or platform error.

### `repositories/device_session_repository.dart`

Hand-written Dio call against the new BFF endpoints. Bypasses the
generated OpenAPI client so the offline-auth ship doesn't block on a
`make flutter-client-gen` round-trip.

### `presentation/cubits/session/session_cubit.dart`

The cubit's `bootstrap()` now:

1. Reads the cached token first and computes the gate offline.
2. *Then* attempts the network refresh — failures don't clear local
   state.
3. If refresh succeeds, fires `_kickDeviceSession()` to mint a fresh
   token and overwrite the cache.

`unlockWithPin` and `unlockWithBiometric` flip the gate to `unlocked`
on success.

## Failure modes

| Scenario                                     | Behaviour                                                                  |
| -------------------------------------------- | -------------------------------------------------------------------------- |
| First launch on a new device                 | `needsOnlineLogin` → must connect for password login + token mint          |
| Cold start, no network, valid cached token   | `locked` → unlock screen → home                                            |
| Cold start, no network, **expired** token    | `expired` → login screen with "session expired" hint                       |
| Stolen unlocked phone, PIN unknown           | After 5 bad PINs → 5-min lockout. Attacker confined to existing ceiling   |
| Server rotates session key, device offline   | `expired` after current token TTL elapses; user re-authenticates online   |
| User changes password on web                 | All sessions revoked → next online refresh fails → cached token survives until expiry; PIN still gates spend |
| BFF restart with ephemeral key (dev)         | All previously issued tokens fail signature verify → `expired`             |

## Threat model — what this defends, what it doesn't

**Defends:**

- Network outage during legitimate use (the whole point).
- Replay of a stolen access JWT: device-session token is bound to
  `device_id`, which is bound to the device's hardware-keystore Ed25519
  keypair. Cloning the JWT to another phone doesn't transfer the
  matching device.
- Brute-force PIN attack: Argon2id (~150 ms/guess) plus 5/5min lockout
  caps an offline attacker at ~720 attempts/hour against a 6-digit PIN
  (search space 1M). With the lockout, exhausting 1M attempts would
  take ~1400 hours = 58 days, by which point the cached token has
  expired and the attacker has nothing.
- Server compromise after token issuance: the offline pubkey on the
  device doesn't change, so even a malicious server can't push fake
  tokens to existing devices without a fresh online round-trip.

**Does not defend:**

- A live attacker with a coerced biometric or known PIN. Limited to
  the offline ceiling; no way around that without server gating.
- A phone compromised at the OS level (root / jailbreak / malicious
  keylogger). The keystore protections are platform-bounded.
- A user who hands their phone + PIN to a friend. Social engineering
  is not in scope.

## Wire-up checklist

Backend:
- [x] `internal/auth/devicesession.go` + tests
- [x] `internal/service/userauth/devicesession.go`
- [x] `internal/transport/http/bff/auth_devicesession.go`
- [x] `cmd/bff/main.go` env + signer wiring
- [x] OpenAPI spec entries (`backend/api/openapi.yaml`)
- [x] `make bff-gen` re-run

Flutter:
- [x] `services/offline_auth.dart` + tests
- [x] `services/biometric_unlock.dart`
- [x] `repositories/device_session_repository.dart`
- [x] `screens/auth/unlock_screen.dart`
- [x] `presentation/cubits/session/session_cubit.dart` (gate state machine)
- [x] `presentation/cubits/session/session_state.dart` (`AuthGate` enum)
- [x] `app.dart` `_RootGate` routes on `gate`
- [x] `core/di/service_locator.dart` registers new services
- [x] `screens/set_pin_screen.dart` mirrors transaction PIN to offline-auth

## Operations

### Generating a stable BFF Ed25519 key (production)

Use `opsctl`:

```sh
# Default: dated key-id (device-session-YYYYMMDD), 14-day TTL
go run ./cmd/opsctl gen-device-session-key

# Override for a named rotation cycle
go run ./cmd/opsctl gen-device-session-key \
    --key-id=device-session-2026q2 \
    --ttl-hours=336
```

Output is the env block ready for your secrets manager:

```
BFF_DEVICE_SESSION_PRIVKEY=<128-hex>
BFF_DEVICE_SESSION_KEY_ID=<kid>
BFF_DEVICE_SESSION_TTL_HOURS=336
```

Stash the values in your secrets manager and inject them via env. Persist
them across deploys — rotating without a transition window will
invalidate every device's cached token mid-flight.

### Rotation (when the time comes)

1. Stand up the new key with a fresh `kid`.
2. Update `Service.ListDeviceSessionPublicKeys()` to return both keys.
3. Wait one TTL (default 14 days) for old tokens to age out
   organically — devices that come online during this window mint
   tokens signed with the new key.
4. Remove the old key from the bundle.

If you need to invalidate immediately (suspected compromise), drop the
old key from `ListDeviceSessionPublicKeys()` right away and accept that
every offline device will see `expired` on next cold start until they
reconnect.

### Forcing a device off the offline path

Server-side: deactivate the device via the existing
`POST /v1/devices/{deviceId}/deactivate`. The next time the device
mints a fresh session token (next online refresh), the issuer returns
`device_inactive`. Tokens already in the wild remain valid until their
`exp`; if you need a hard cut, rotate the signing key.

User-side: open Settings → "Sign out" (calls `SessionCubit.logout`)
which clears the cached token, the PIN hash, and the device-scoped
keys.
