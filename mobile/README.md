# SACCO mobile app (Flutter)

Member self-service app for Android and iOS, talking to the same Django API
as the web frontend. One build serves every SACCO on the platform. The
member types their **SACCO code** (the first label of the SACCO's domain,
e.g. `nairobi`), and the app resolves it through the public endpoint
`GET /api/public/saccos/<code>/` (`backend/tenants/views.py`), then talks to
that SACCO's own domain. That's how django-tenants picks the schema.

Leaders and staff log in too. Members get Home, Savings, Loans and Welfare. Anyone
with a leadership role also gets a **Leader** tab with the modules their role unlocks.
When both sets of tabs are present, Profile moves to the person icon at the top right.
A login with neither is turned away with an explanation.

## Leader modules

| Module | Who (default roles) | What they can do |
|---|---|---|
| Finance | Treasurer, Accountant, Auditor (read-only), SuperAdmin | Financial position dashboard; journal (view, post manual entries, reverse with a reason); chart of accounts (add accounts) |
| Reports | Anyone with the matching data permission | Trial balance, statement of financial position, income statement, general ledger, day book, member balances with control-account reconciliation, loan portfolio with arrears ageing and PAR, mobile money collections, dividend/interest register. All can be shared as CSV with an audit header (SACCO, period, prepared by, time) |
| Loan desk | Loan Officer (appraise), Credit Committee (approve/reject), Treasurer (disburse), Teller/Branch Manager (record repayments) | Queues by stage, with the action each role can take |
| Members | Anyone with `members.view` | Search, member record, KYC verification, counter deposit / withdrawal / share purchase, welfare payment |
| Dividends & interest | Treasurer, Accountant, Board | Propose, approve or reject (never your own proposal), pay out |
| Welfare administration | Welfare Manager, Treasurer, Board | Cases, counter, rules, year end |

The Leader tab opens with a **Needs your attention** list (loans to appraise, decide or
disburse, and runs or welfare cases to approve), counted for that person's role only.

Manual journal entries can't touch member control accounts (savings, shares, loans,
welfare). Those move only through their own screens, so every member's balance keeps
reconciling to the ledger.

## What's in v1

| Area | Screens / behaviour | Backend endpoints |
|---|---|---|
| Onboarding | SACCO code → phone + password login | `public/saccos/<code>/`, `auth/token/` |
| Security | Tokens in Android Keystore / iOS Keychain; optional fingerprint/Face ID unlock (local only); single-flight token refresh | `auth/token/refresh/` |
| Home | Share capital, savings (ledger total), loan balance, next instalment, arrears, pending guarantee requests, recent payments | `savings/me/statement/`, `loans/me/`, `loans/me/guarantee-requests/`, `payments/me/collections/` |
| Savings | Shares vs deposits kept separate; history per account; pledged-amount lock shown | `savings/me/statement/`, `savings/products/` |
| Pay | Buy shares / deposit via mobile money (M-Pesa or Selcom, per SACCO config), with an idempotency key reused on retry, then live status polling | `payments/me/collect/`, `payments/me/collections/<id>/` |
| Loans | List, detail (schedule, repayments, guarantors), apply, add guarantor by member number, submit for appraisal, accept/decline guarantee requests with explicit consent | `loans/*` self-service endpoints |
| Dividends | Dividend and interest history with WHT | `distributions/me/` |
| Profile | KYC details (read-only), edit contact details, change password, language (EN/SW), switch SACCO, log out | `members/me/`, `auth/me/change-password/` |
| Welfare (member) | Welfare balance, amount owed, progress on the yearly contribution, case contributions, payments; pay by mobile money | `welfare/me/`, `payments/me/collect/` (purpose `WELFARE_CONTRIBUTION`) |
| Welfare (staff) | Open cases (WelfareManager), approve or reject (Treasurer; never the person who opened it), record cash/bank payouts capped at what was collected, see who still owes, counter payments, edit rules (BoardMember), close the year | `welfare/*` |

Money is `Decimal` end to end (`lib/core/money.dart`). Amounts arrive as
strings and are never parsed through `double`.

## Running

```bash
cd mobile
flutter pub get
flutter test                 # money parsing/formatting tests
flutter run                  # Android emulator by default
```

Build-time settings (`lib/config.dart`), passed with `--dart-define`:

| Define | Default | Meaning |
|---|---|---|
| `PUBLIC_API_BASE_URL` | `http://10.0.2.2:8000` | A host matching **no** tenant, so it hits the public schema (SACCO lookup). `10.0.2.2` is the Android emulator's alias for your PC. |
| `TENANT_SCHEME` | `http` | `https` in production |
| `TENANT_PORT` | `8000` | Blank in production |
| `TENANT_CONNECT_OVERRIDE` | *(blank)* | Connect to this origin and send the SACCO's domain only as the `Host` header. Use it when the tenant domain doesn't resolve from the phone. |

### Local backend + Android emulator

`nairobi.localhost` can't resolve from an emulator or phone, so use the
override to reach the dev server while still routing to the right tenant:

```bash
flutter run \
  --dart-define=PUBLIC_API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=TENANT_CONNECT_OVERRIDE=http://10.0.2.2:8000
```

Then enter SACCO code `nairobi`. The root README's demo users are
SuperAdmin staff with no member record, so they see only the Leader and
Profile tabs. To see the member screens, invite a member to the
portal from the web app and log in as them.

### Remote server (nip.io, as in the root README)

```bash
flutter run \
  --dart-define=PUBLIC_API_BASE_URL=http://<ip>:8000 \
  --dart-define=TENANT_PORT=8000
```

The lookup prefers the tenant's `*.<TENANT_BASE_DOMAIN>` domain (e.g.
`nairobi.<ip>.nip.io`) over `.localhost`, so no override is needed.

### Production

```bash
flutter build appbundle \
  --dart-define=PUBLIC_API_BASE_URL=https://saccoplatform.com \
  --dart-define=TENANT_SCHEME=https --dart-define=TENANT_PORT=
```

Cleartext HTTP is allowed only in Android **debug** builds
(`android/app/src/debug/AndroidManifest.xml`).

## Welfare needs a Celery worker

Approving a case queues the levy over all members as a Celery task, and so
does closing a year. Without a worker running (`celery -A config worker`),
cases stay on "Charging members…". For quick local testing you can set
`CELERY_TASK_ALWAYS_EAGER=True` in the backend `.env` instead.

## Not in v1 (needs backend work first)

- **Loan repayment via mobile money.** `payments.CollectionPurpose` has no
  `LOAN_REPAYMENT`, and `loans/<id>/repay/` is staff-only (`loans.repay`).
- **Withdrawals.** Staff-only today (`savings.deposit`/withdraw views).
- **Push notifications.** The backend already stores `android`/`ios`
  device tokens (`POST /api/auth/push/devices/`), but the app needs a
  Firebase project (`google-services.json` / `GoogleService-Info.plist`)
  before `firebase_messaging` can be added.
