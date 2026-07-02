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

`DJANGO_ALLOWED_HOSTS` includes a leading-dot wildcard (`.localhost`), so
new tenant domains work immediately without editing `.env` per SACCO - this
matters for self-service sign-up (below), where there's no one available to
edit settings by hand. In production, set the wildcard to your real domain
(e.g. `.saccoplatform.com`) via `TENANT_BASE_DOMAIN`.

## Accessing this from outside the server (cloud/remote)

Django (`:8000`) and Next.js (`:3000`) both bind `0.0.0.0`, so nothing at
the OS level blocks remote access - but reachability from the internet
also depends on this VM's cloud firewall (Azure Network Security Group),
which isn't configured from inside the box. Open inbound TCP 3000 and 8000
there if you need real remote/browser access.

Postgres/Redis/MinIO are deliberately bound to `127.0.0.1` only in
`docker-compose.yml` - they should never be reachable from outside this
host, regardless of NSG rules, since they hold live data behind
demo-grade local credentials.

**Multi-tenant domain routing does not work over a raw IP.** Two reasons:
`.localhost` domains (used for local dev) are hardcoded by every browser to
resolve to loopback, so they can never work remotely no matter the DNS; and
hitting the bare IP sends a `Host` header that matches no tenant, so
`django-tenants` falls back to the public schema (admin + sign-up only, not
any SACCO's login/data).

The fix used here without owning a domain yet: **nip.io**, a free wildcard
DNS-over-IP service - `anything.<your-ip>.nip.io` publicly resolves to
`<your-ip>`. That keeps real per-tenant domain routing working over the
internet. To set it up for a given server IP:

```bash
# backend .env
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,.localhost,<ip>,.<ip>.nip.io
TENANT_BASE_DOMAIN=<ip>.nip.io
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://<ip>:3000
# CORS_ALLOWED_ORIGIN_REGEXES is derived from TENANT_BASE_DOMAIN
# automatically in settings.py - no per-tenant CORS config needed.
```

New sign-ups (`/signup-sacco`) automatically get a `*.<ip>.nip.io` domain
once `TENANT_BASE_DOMAIN` is set this way. For existing tenants, add a
second (non-primary) `Domain` row rather than replacing the `.localhost`
one - both keep working:

```python
Domain.objects.create(domain="nairobi.<ip>.nip.io", tenant=tenant, is_primary=False)
```

This is a bridge for testing/demoing before a real domain exists - swap
`TENANT_BASE_DOMAIN` for a real wildcard-DNS domain before any actual
production/customer traffic.

**The frontend needs no per-tenant configuration at all.** `lib/api.ts`
derives the API origin from whatever hostname the browser is actually on
(`window.location.hostname`, same port pattern, `:8000`) rather than a
static `NEXT_PUBLIC_API_BASE_URL` - so `dar.<ip>.nip.io:3000` automatically
talks to `dar.<ip>.nip.io:8000`, `nairobi.*` talks to `nairobi.*`, and any
future tenant's subdomain just works the moment it's provisioned. Two
things had to be true for this to actually work when visiting a non-default
hostname, both now handled in `next.config.ts` / `config/settings.py`:

- **Next.js's dev-server DNS-rebinding protection** blocks cross-origin
  requests to dev-only assets (HMR, font proxying, ...) by default -
  visiting anything other than `localhost` 403s on those without
  `allowedDevOrigins` listing the tenant domain patterns.
- **CORS** must allow the *specific* origin the browser is on. A fixed
  `CORS_ALLOWED_ORIGINS` list can't keep up with dynamically-created tenant
  subdomains, so `CORS_ALLOWED_ORIGIN_REGEXES` matches any subdomain of
  `TENANT_BASE_DOMAIN` instead.

`NEXT_PUBLIC_API_BASE_URL` still works as an explicit override (pins every
request to one fixed tenant regardless of hostname) if you ever need it.

## Self-service SACCO sign-up (30-day free trial)

A public, unauthenticated endpoint provisions a brand new SACCO - its own
schema, RBAC roles, and a SuperAdmin owner account - with a 30-day trial,
no payment step:

```
POST /api/onboarding/signup/
{"sacco_name": "...", "country": "KE"|"TZ",
 "first_name": "...", "last_name": "...",
 "phone_number": "+254...", "password": "..."}
```

Frontend: `/signup-sacco` (linked from the home page as the primary CTA).

This only works because the request resolves to the **public schema**, not
a tenant - django-tenants falls back to `config.urls_public` (see
`PUBLIC_SCHEMA_URLCONF` / `SHOW_PUBLIC_IF_NO_TENANT_FOUND` in
`config/settings.py`) for any hostname that doesn't match an existing
tenant's domain. The frontend calls it via a separate env var,
`NEXT_PUBLIC_PUBLIC_API_BASE_URL` (plain `http://localhost:8000` in dev),
distinct from the per-tenant `NEXT_PUBLIC_API_BASE_URL` used everywhere
else.

`subscriptions.Subscription.status` starts at `trialing` with
`trial_ends_at = now + 30 days`. Nothing currently upgrades it to `active`
automatically - real billing collection needs Phase 3 (`payments`) +
Phase 7 (`subscriptions`) first, so for now that's a manual flip in Django
admin once payment is arranged out of band. Login **is** enforced against
trial expiry, though (`TenantScopedTokenObtainPairSerializer` in
`identity/serializers.py`): once `trial_ends_at` passes with no active
subscription, that SACCO's users can no longer obtain a token.

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
- **Subscriptions:** `subscriptions` app (public-schema) - self-service
  SACCO sign-up with a 30-day free trial. See dedicated section below.

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
