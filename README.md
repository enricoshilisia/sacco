# SACCO Platform

Multi-tenant SACCO management platform for Kenya and Tanzania. See
[`CLAUDE.md`](CLAUDE.md) for the non-negotiable domain/correctness rules and
[`BUILD_PLAN.md`](BUILD_PLAN.md) for the phased build plan. This README
covers how to actually run what's been built so far (Phase 0: Foundation).

## Stack

- **Backend:** Django 5 + DRF, `django-tenants` (schema-per-tenant), Celery + Redis
- **Frontend:** Next.js 16 (App Router, Turbopack), TypeScript, Tailwind v4, `next-intl`
- **DB / cache / storage:** PostgreSQL, Redis, MinIO (S3-compatible) - all via Docker Compose
- **Auth:** JWT (phone number + password) and WebAuthn (biometric/passkey)
- **Push:** Firebase Cloud Messaging (web push)

## One-time setup

```bash
cp .env.example .env                      # edit values as needed
docker compose up -d                      # postgres, redis, minio

cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate_schemas --shared

# create a tenant (repeat per SACCO)
python manage.py provision_tenant --name "Nairobi Demo SACCO" \
  --schema nairobi_demo --domain nairobi.localhost --country KE
```

`provision_tenant` creates the Postgres schema, runs all tenant-app
migrations inside it, and seeds the default RBAC role/permission catalog
(see `accesscontrol/migrations/0003_seed_default_permissions_and_roles.py`).

For local dev, add every tenant domain you create to `DJANGO_ALLOWED_HOSTS`
in `.env` (comma-separated) - `django-tenants` routes by the request's Host
header, and Django will 400/404 requests for hosts not in that list.

## Running

```bash
# backend - served over ASGI via Daphne, not the WSGI dev server.
# `daphne` is listed first in INSTALLED_APPS, so `runserver` itself is
# Daphne-backed (its access log format - "HTTP GET /path 200 [...]" -
# confirms this). To run Daphne directly instead: daphne -b 0.0.0.0 -p 8000 config.asgi:application
cd backend && source venv/bin/activate
python manage.py runserver 0.0.0.0:8000

# celery worker (money math, notifications, push - Phase 3+)
celery -A config worker -l info

# frontend
cd frontend
npm install
cp .env.local.example .env.local          # point NEXT_PUBLIC_API_BASE_URL at a tenant
npm run dev
```

Because tenants are routed by domain, requests to the backend must carry the
right `Host` header:

```bash
curl -H "Host: nairobi.localhost" http://localhost:8000/api/auth/token/ \
  -X POST -d '{"phone_number":"+254700000001","password":"..."}' \
  -H "Content-Type: application/json"
```

The frontend's `NEXT_PUBLIC_API_BASE_URL` should be set to the full tenant
origin (e.g. `http://nairobi.localhost:8000`) so the browser's `Host` header
matches automatically.

## What's implemented (Phase 0)

- **Multi-tenancy:** `django-tenants` schema-per-tenant. `tenants.Tenant` /
  `tenants.Domain` live in the public schema; `provision_tenant` creates both
  and auto-migrates the new schema.
- **Identity:** shared (public-schema) `identity.User` keyed by phone
  number - one person can belong to multiple SACCOs. `identity.TenantAccess`
  records which SACCOs a user can log into. Login is tenant-scoped: a JWT
  obtained against one SACCO's domain is rejected if the user has no
  `TenantAccess` to that SACCO (`identity/serializers.py:TenantScopedTokenObtainPairSerializer`).
- **Biometric auth:** WebAuthn registration + passwordless login
  (`identity/webauthn_service.py`, endpoints under `/api/auth/webauthn/...`).
  Needs a real browser with a platform authenticator to exercise end-to-end -
  not testable via curl.
- **Push notifications:** Firebase Cloud Messaging. Backend stores device
  tokens (`identity.PushDeviceToken`); frontend registers a token on login
  via a hand-written `/sw.js` service worker (see note below on why it's
  hand-written, not plugin-generated).
- **RBAC:** `accesscontrol` app (tenant-schema). Custom `Permission`/`Role`
  models (not Django's built-in auth Group/Permission - deliberately, since
  roles need to be tenant-scoped and business-domain-shaped). Seeded system
  roles: SuperAdmin, BranchManager, Teller, LoanOfficer, CreditCommittee,
  Accountant, Auditor, BoardMember, CommitteeMember, Member, Guarantor.
- **Configuration:** `configuration.TenantConfig` (tenant-schema) - ID types,
  loan multiplier, WHT rate placeholders, active SMS/payment provider. All
  data, no `if country == "KE"` branches per CLAUDE.md rule 6.
- **i18n:** English + Swahili, both backend (`LANGUAGES` in
  `config/settings.py`) and frontend (`next-intl`, locale-prefixed routes
  `/en/...`, `/sw/...`).
- **PWA:** installable manifest (`app/manifest.ts`), mobile-first Tailwind
  UI, hand-written offline-shell + push service worker at `/sw.js`.

### Note on the PWA service worker

Next.js 16 defaults to Turbopack for both `next dev` and `next build`.
Community PWA plugins (`next-pwa`, Serwist) still hook into webpack's
compiler and silently produce no service worker under Turbopack - confirmed
against `node_modules/next/dist/docs/.../progressive-web-apps.md`, which now
recommends hand-writing `public/sw.js` for this exact reason. This repo
follows that guidance: `src/app/sw.js/route.ts` is a Route Handler (not a
static file) so the Firebase config can be injected from env vars at
request time.

## SMS / payment providers (config, not code branches)

Configured per tenant via `configuration.TenantConfig.active_sms_provider` /
`active_payment_provider`, with credentials in `.env`:

- Kenya SMS: **HostPinnacle** (primary)
- Tanzania SMS: **Beem Africa** (primary)
- Backup SMS (both countries): **Africa's Talking**
- Kenya payments: **Daraja** (M-Pesa)
- Tanzania payments: **Selcom**

Adapters implementing `NotificationProvider` / `PaymentProvider` land in
Phase 3 per `BUILD_PLAN.md` - the config surface exists now so Phase 3 is a
provider-adapter exercise, not a re-architecture.

## Demo tenants / users (local dev only - change or remove before any shared deployment)

| SACCO | Schema | Domain | Country | Demo user | Password |
|---|---|---|---|---|---|
| Nairobi Demo SACCO | `nairobi_demo` | `nairobi.localhost` | KE | `+254700000001` | `DemoPass123!` |
| Dar es Salaam Demo SACCO | `dar_demo` | `dar.localhost` | TZ | `+255700000002` | `DemoPass123!` |

Both are SuperAdmin in their own SACCO only - cross-tenant login is rejected
by design (see Identity section above).

## Next steps

Per `BUILD_PLAN.md`: Phase 1 (`members`), then Phase 2
(`accounting` + `savings` together - "the make-or-break slice"). Don't skip
ahead to payments/loans before the ledger is proven.
