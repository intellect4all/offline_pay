# OfflinePay Backoffice Dashboard

Internal Nuxt 3 + Vue 3 + Pinia dashboard for the OfflinePay team. Talks to the Go `cmd/adminapi` service (default `:8081`) via a thin Nuxt server-side BFF that keeps access/refresh tokens in httpOnly cookies — so the browser never holds a raw JWT.

## Quick start

```bash
# 1. Start infra + adminapi (compose brings up everything, or cherry-pick)
docker compose up -d postgres redis adminapi

# 2. Seed a superadmin (one-off)
cd backend
go run ./cmd/opsctl admin-create --email you@example.com --name "You" --roles SUPERADMIN

# 3. Run the dashboard
cd ../dashboard
pnpm install
pnpm dev
# open http://localhost:3000
```

Docker-compose also ships a `dashboard` service if you'd rather run it alongside the rest of the stack.

## Environment

| Var                    | Default                  | Purpose                             |
|------------------------|--------------------------|-------------------------------------|
| `NUXT_ADMIN_API_URL`   | `http://localhost:8081`  | Base URL of the Go adminapi.        |
| `NUXT_PUBLIC_APP_NAME` | `OfflinePay Backoffice`  | Header title.                       |

## What's in scope today

- **Auth + RBAC.** Email + bcrypt login, refresh sessions, five seeded roles — `VIEWER`, `SUPPORT`, `FINANCE_OPS`, `FRAUD_OPS`, `SUPERADMIN` — from migration `0014`. Grants live in `admin_user_roles`.
- **Overview** — high-level stats + 14-day volume sparkline.
- **Users** — list + detail pages (accounts, devices, ceilings, fraud, recent transactions).
- **Transactions** — list + detail backed by the `transactions` business-event log (migration `0018`).
- **Settlement batches** — list + detail.
- **Fraud** — signals + scores stream (`fraud_signals` for cryptographic/offline anomalies; `fraud_scores` for online-transfer rules).
- **Audit log** — `SUPERADMIN`-only view of `admin_audit_log` (who did what, with payload + IP).

## Source layout

```
dashboard/
├── app.vue · nuxt.config.ts · package.json
├── pages/
│   ├── index.vue · login.vue
│   ├── users/{index,[id]}.vue
│   ├── transactions/{index,[id]}.vue
│   ├── settlements/{index,[id]}.vue
│   └── fraud/index.vue
├── components/           # DataTable · KYCCard · KoboAmount · StatCard · StateBadge
├── composables/useKobo.ts
├── layouts/ · middleware/ · plugins/ · stores/
└── server/               # Nuxt server routes that proxy adminapi + own the cookie jar
```

## Follow-ups

KYC management UI, fraud ops console, analytics / volume charts, admin-user management, audit-log filtering, devices registry, CSV export, TOTP 2FA enrollment UI, reconciliation runs UI.
