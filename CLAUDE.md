# CLAUDE.md — SACCO Platform

Multi-tenant SACCO management platform for Kenya and Tanzania. SaaS (subscription) with an on-premises deployment path. Read this fully before writing code. These rules are non-negotiable because this system moves real member money and is regulated (SASRA in Kenya, BOT/TCDC in Tanzania).

## Stack

- **Backend:** Django + Django REST Framework
- **Frontend:** Next.js (separate repo/app, talks to the API)
- **Async:** Celery + Celery Beat, Redis broker
- **DB:** PostgreSQL
- **Multi-tenancy:** schema-per-tenant via `django-tenants`
- **Object storage:** S3-compatible (MinIO on-prem, so `documents` code is identical either way)

## Non-negotiable correctness rules

1. **Money is `Decimal`, never `float`.** Ever. All monetary fields use `DecimalField`. All arithmetic on money uses `Decimal`. No exceptions.
2. **Every balance change goes through a double-entry journal entry.** Never write to an account balance directly. A balance is the sum of its journal lines. If code mutates a balance without a balanced (debits == credits) journal entry, it is a bug.
3. **Journal is append-only.** No editing or deleting posted entries. Corrections are reversing entries. This is an audit requirement, not a preference.
4. **Idempotency on every payment operation.** Every collection/disbursement carries an idempotency key. Payment provider callbacks WILL be delivered more than once; a retried callback must never double-post to the ledger.
5. **Share capital ≠ deposits.** These are different account types with different rules (see Domain rules). Do not conflate them. This is the single most common way naive SACCO systems become incorrect.
6. **Country differences are configuration, not code branches.** ID types, tax rates, loan multipliers, regulatory formats, currency — all per-tenant/per-country config. No `if country == "KE"` scattered through business logic.
7. **Money math runs in Celery, is retryable, and is logged.** Interest accrual, penalties, dividend runs, reconciliation — all async, all idempotent, all auditable.

## Domain rules that are easy to get wrong

- **Share capital** is non-withdrawable (except on member exit), earns **dividends** (declared at AGM), and represents ownership. It is NOT the loan security base.
- **Deposits/savings** are withdrawable, earn **interest/rebate**, and ARE the basis for the **loan multiplier** (e.g. borrow up to 3× deposits). Multiple savings products exist (mandatory monthly, voluntary, fixed/term, goal, junior).
- **Guarantors pledge their own deposits as security** for another member's loan. A pledge locks that portion of the guarantor's deposits — it must be tracked, and it reduces what the guarantor can themselves borrow/withdraw. Pledges need explicit consent.
- **Check-off / employer remittance:** employers send a lump sum covering many members' deductions; the system must split and reconcile it against individual member accounts. First-class feature in Kenya.
- **Withholding tax** applies to dividends/interest at rates that differ by country and change over time. Never hardcode a rate — config, and flag for a tax adviser to confirm current values.
- **Loan interest:** support both reducing-balance and flat methods; the method is per loan product config.

## App boundaries

Shared (public schema): `tenants`, `subscriptions`, `platform_admin`, `identity`
Tenant (per-SACCO schema): `members`, `savings`, `loans`, `accounting`, `distributions`, `investments`, `governance`, `discussions`, `documents`, `compliance`, `reports`
Cross-cutting (shared code, per-tenant data/config): `payments`, `notifications`, `rules_engine`, `configuration`, `audit`, `core`

Keep each app a clean bounded context. Business logic lives in services, not in views or serializers. Views are thin.

## Provider abstractions

- **`notifications`:** provider-agnostic `NotificationProvider` interface with adapters (Africa's Talking, Twilio, Infobip for KE; Beem, NextSMS for TZ). Active provider is per-tenant config. Swapping providers is a config change, never code.
- **`payments`:** `PaymentProvider` interface — `initiate_collection()`, `initiate_disbursement()`, webhook handler. Adapters: M-Pesa (Daraja STK/B2C), KE bank APIs, Selcom (TZ, primary) + others. Every callback verifies signature, runs in Celery, posts to the ledger, is idempotent.

## Working conventions

- Scope each session to ONE app or ONE vertical slice. Do not try to build the whole system in one pass — it wrecks context and correctness.
- Write tests for anything touching money. A savings deposit, a loan repayment, a dividend run — each needs a test proving the ledger balances after.
- Migrations are per-tenant-aware. Verify migration behavior under `django-tenants` before batch-running.
- Swahili/English localization from the start; user-facing strings are translatable.
- When in doubt about a domain rule, ask rather than guess — a wrong assumption about money is expensive.
