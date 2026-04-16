# OfflinePay

Offline-first C2C QR payments for Nigeria. Payments work in airplane mode and settle when connectivity returns. Built around Ed25519-signed ceiling tokens, receiver-issued PaymentRequests, two-phase settlement, gossip propagation, and two-layer encryption.

## Status

PoC complete across phases 0–12 of `docs/BUILD_PLAN.md`. Protocol shifted twice during the build — PaymentRequest binding (migration `0024`) and ceiling recovery (migrations `0022`–`0023`). Production hardening (HSM-backed device keys, production attestation, edge TLS) is outstanding.

| Area | State |
|------|-------|
| Crypto core (Go + Dart) | Done — byte-identical cross-language fixture. |
| Postgres schema + SQLC | Migrations 0001–0025. |
| Wallet / ceiling service (+ recovery) | Done. |
| Two-phase settlement + PaymentRequest binding | Done. |
| Identity / DisplayCard | Done. |
| Reconciliation (sync + nightly ledger) | Done — cron 03:00 UTC inside BFF. |
| OpenAPI HTTP contract + BFF | Done. |
| Flutter C2C app (QR + NFC, offline auth, fraud loop) | Done. |
| Gossip + two-layer encryption | Done. |
| Fraud scoring (offline signals + online transfer rules) | Done. |
| Transactional outbox for online transfers (`cmd/transferworker`) | Done. |
| Admin API + Nuxt dashboard (RBAC, audit log) | Done — follow-ups tracked. |
| Observability (OTel, Prom, Grafana, Loki, Tempo, Metabase) | Done. |
| Production key custody (KMS, StrongBox/Secure Enclave), edge TLS, live attestation | Deferred. |

## Documentation

| Doc | What it covers |
|-----|----------------|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System overview, topology, account model, happy-path sequence, ceiling recovery, file trees. |
| [`docs/PROTOCOL.md`](docs/PROTOCOL.md) | Token formats (incl. `DisplayCard`, `PaymentRequest`), canonical encoding, AES-GCM, sealed box, animated QR, NFC APDU, gossip, settlement math, key rotation. |
| [`docs/API.md`](docs/API.md) | HTTP API reference — auth, wallet, settlement, keys, devices, identity, idempotency rules. |
| [`docs/OFFLINE_AUTH.md`](docs/OFFLINE_AUTH.md) | Cold-start authentication without connectivity (device-session tokens, biometric/PIN gate). |
| [`docs/RUNBOOK.md`](docs/RUNBOOK.md) | First-time setup, key rotation, recovery, nightly recon, triage, alerting, emergency procedures. |
| [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) | Contributor guide — prerequisites, codegen, per-service checklist, conventions, testing. |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Threat model, defences with code references, deferred work, disclosure policy. |
| [`docs/WHITEPAPER.md`](docs/WHITEPAPER.md) | Long-form design paper. |
| [`CLAUDE.md`](CLAUDE.md) | Domain primer and code conventions. |
| [`backend/DOCS.md`](backend/DOCS.md) | Engineering documentation for the Go backend. |
| [`mobile/packages/core/README.md`](mobile/packages/core/README.md) | Dart crypto + protocol core. |
| [`mobile/app/README.md`](mobile/app/README.md) | Flutter C2C app. |
| [`dashboard/README.md`](dashboard/README.md) | Backoffice Nuxt dashboard. |

## Quick start

```bash
git clone <repo> offline_pay && cd offline_pay
docker compose up -d                 # Postgres, Redis, NATS, bff, adminapi, transferworker,
                                     # dashboard, Prometheus, Grafana, Loki, Tempo, Metabase
cd backend
make sqlc                            # regenerate SQLC output
make proto                           # regenerate protobuf DTOs
make bff-gen                         # regenerate BFF server from OpenAPI
make migrate                         # apply 0001–0025
make check                           # vet + unit + dart (fast)

# Optional: smoke test against a live Postgres
make e2e

# Flutter app
cd ../mobile/packages/core && dart test
cd ../../mobile/app          && flutter test
```

See `docs/RUNBOOK.md` for seeding bank / realm / sealed-box keys before running the server, and `docs/DEVELOPMENT.md` for the full toolchain setup.

## License

TBD.
