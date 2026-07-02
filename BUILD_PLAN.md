# SACCO Platform — Build Plan

Two-part strategy: **build the base correctly**, then **assemble a demo slice for the Tanzania customer** on top of it. Nothing built for the base is thrown away — the base is what makes the demo credible.

Sequence phases in order. Do not start a phase until the previous one's vertical slice works and (where money is involved) reconciles. Scope each Claude Code session to one phase, ideally one app.

---

## PART A — THE BASE

### Phase 0 — Foundation
**Apps:** `core`, `tenants`, `configuration`, `identity`
**Goal:** A tenant can be provisioned into its own schema; a user can authenticate into it; per-tenant/per-country config exists.
- `core`: base models, Money/Decimal helpers, currency, localization scaffolding, audit mixin.
- `tenants`: `django-tenants` setup, schema provisioning, domain routing, country/currency binding.
- `configuration`: per-tenant config (ID types, currency, tax placeholders, loan-multiplier defaults). Config-not-code enforced here.
- `identity`: auth, user↔tenant mapping. Decide now: can one person belong to multiple SACCOs?
**Done when:** two tenants exist in separate schemas, each with a logged-in user seeing only their own data.
**Landmines:** get `django-tenants` migration behavior right now; retrofitting multi-tenancy later is brutal.

### Phase 1 — Members
**App:** `members`
**Goal:** Full membership lifecycle.
- Member records, categories (ordinary/associate/junior/corporate/dormant), KYC, next-of-kin/nominees/beneficiaries.
- Guarantor relationship graph (structure only; pledge logic comes with loans).
- ID type driven by config (National ID/Huduma for KE, NIDA for TZ).
**Done when:** a member and their family/nominees can be registered under a tenant, with country-appropriate ID capture.

### Phase 2 — Savings + Accounting (build together)
**Apps:** `accounting` FIRST, then `savings`
**Goal:** The correctness core. Never bolt accounting on later.
- `accounting`: chart of accounts, append-only journal, member sub-ledgers reconciled to control accounts, trial balance.
- `savings`: share capital (non-withdrawable, dividend-bearing) vs. savings products (withdrawable, interest-bearing, loan-multiplier base). Standing orders / check-off structure.
- Every savings transaction posts a balanced journal entry.
**Done when:** a member makes a share-capital contribution AND a savings deposit; both post to the ledger; trial balance balances; member statement reconciles to control accounts. **This is the make-or-break slice — prove it before going further.**
**Landmines:** share-vs-deposit distinction; every path posts double-entry; Decimal everywhere.

### Phase 3 — Payments + Notifications
**Apps:** `payments`, `notifications`
**Goal:** Money in/out and messaging, both provider-agnostic.
- `notifications`: `NotificationProvider` interface + one KE and one TZ adapter; per-tenant provider config; Celery-sent; delivery log.
- `payments`: `PaymentProvider` interface; M-Pesa (Daraja) + Selcom adapters; STK-push collection → posts to ledger; idempotency keys; signature-verified callbacks via Celery; daily reconciliation job.
**Done when:** an M-Pesa (and a Selcom) collection lands as a savings deposit in the ledger, idempotently, and an SMS confirmation fires.
**Landmines:** idempotency (callbacks arrive twice); every payment posts double-entry; verify signatures.

### Phase 4 — Loans
**App:** `loans` (+ `rules_engine` starts here)
**Goal:** The revenue engine, done correctly.
- Loan products (reducing-balance vs flat, term, max as multiple of deposits, eligibility rules).
- Application → appraisal → approval hierarchy.
- Guarantor allocation, consent, and **pledge** (locks guarantor deposits, reduces their available balance).
- Disbursement (M-Pesa/bank/internal), amortization schedule, repayments, arrears aging, rescheduling.
- `rules_engine`: declarative eligibility rules (customer's auto grant/deny requirement).
- CRB integration stub for KE (Metropol/TransUnion/Creditinfo) — real integration later.
**Done when:** a member applies, guarantors pledge, rules engine approves/denies, loan disburses to the ledger, and a repayment posts correctly with arrears tracked.
**Landmines:** guarantor pledge accounting; reducing-balance math; every movement double-entry.

### Phase 5 — Distributions
**App:** `distributions`
**Goal:** Dividends on shares, interest/rebate on deposits.
- Distribution runs, WHT handling (config rates, flagged for tax adviser), posting to ledger, member notifications.
**Done when:** a dividend run distributes to members' share capital and posts correctly with WHT withheld.

### Phase 6 — Governance
**App:** `governance` (+ `discussions`, `documents`)
**Goal:** The cooperative layer — this is what makes it a SACCO, and much of it maps directly to the customer's 17 points.
- Meetings (AGM/SGM/board/committee), notices + SMS, agendas.
- Attendance + automatic penalties (posts to ledger as a member charge).
- Minutes upload immediately post-meeting.
- E-voting + resolutions, elections, delegates model.
- Constitution rules driving behavior (via `rules_engine`).
- `discussions`: member forum, proposals, feedback.
- `documents`: media archive (photos, audio, minutes) on S3/MinIO.
**Done when:** a meeting can be called with SMS notice, attendance taken with auto-penalty, minutes uploaded, and a resolution voted on.

### Phase 7 — Subscriptions + Compliance + Reports
**Apps:** `subscriptions`, `compliance`, `reports`
**Goal:** Make it a sellable SaaS and a compliant one.
- `subscriptions`: plans, feature flags/gating, grace/suspension (read-only when unpaid, never data loss), billing via your own `payments` layer.
- `compliance`: SASRA (KE) and BOT/TCDC (TZ) returns as pluggable per-country modules. **Confirm current return formats before building — they change.**
- `reports`: statements, dashboards, analytics.

---

## PART B — TANZANIA DEMO SLICE

Assemble on top of the base once Phases 0–4 (at least through Loans, ideally Governance) are solid. The demo is a **configuration and presentation** exercise, not new architecture — that's the payoff of building the base right.

**Configure a Tanzania tenant:**
- Country config: TZS currency, NIDA ID type, Swahili as primary UI language.
- Notifications: Beem or NextSMS adapter active.
- Payments: Selcom adapter active.
- TZ-appropriate loan products and multipliers.

**Showcase flow (maps to the customer's stated needs):**
1. Register members + families (needs 1, 3).
2. Member logs in with security code, views their shares/contributions history (needs 2, 3).
3. Record a Selcom contribution → SMS confirmation fires (needs 6, plus the payment rail).
4. Show consolidated, reconciled totals of shares + dividends (needs 4, 5).
5. Call a meeting → SMS notices → take attendance with auto-penalty → upload minutes (needs 8, 10, 15).
6. Run a vote / resolution (need 9).
7. Loan application → rules-engine auto grant/deny with guarantor pledge (needs 11, 13).
8. Show the constitution driving a rule (need 12), and the discussion forum (need 7).

Prioritize the flows that are visually convincing and prove correctness (the reconciled totals and the auto grant/deny are the "wow" moments for a SACCO audience). Video conferencing (need 16) can be a Jitsi embed shown last if time allows.

---

## Working notes for Claude Code sessions

- One phase per session where possible; one app at a time keeps context small and budget efficient.
- Tests for every money path before moving on.
- After each phase, confirm the vertical slice works end-to-end before starting the next.
- Keep `CLAUDE.md` authoritative — if a rule there is wrong or missing, fix it there, not in ad-hoc prompts.
