"""
Financial and audit reports, computed from the ledger (never from stored
balances - CLAUDE.md rule 2). Every report returns the same shape so one
viewer (mobile/web) and one CSV exporter can handle all of them:

    {
      "key": ..., "title": ..., "period": "...",
      "summary": [{"label": ..., "value": ..., "kind": "money|text|number|percent"}],
      "sections": [{
          "title": ...,
          "columns": [{"key": ..., "label": ..., "kind": ...}],
          "rows": [[...], ...],          # values in column order, money as strings
          "totals": [...] | None,
      }],
      "checks": [{"label": ..., "ok": bool, "detail": ...}],   # reconciliation checks
    }

Money is Decimal throughout and serialised as strings (CLAUDE.md rule 1).
These are management and audit working reports. They are NOT regulator
returns in SASRA/BOT/TCDC format - those need their current official
templates confirmed first (CLAUDE.md, Phase 7 compliance).
"""

from collections import defaultdict
from datetime import date, timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.db.models import Sum
from django.utils.translation import gettext as _

from accounting.models import DEBIT_NORMAL_TYPES, Account, AccountType, JournalEntry, JournalLine

ZERO = Decimal("0")
CASH = "1000"
SAVINGS = "2000"
SHARES = "3000"
LOANS = "4000"
WELFARE_DUES = "1300"
WELFARE_PREPAID = "2400"
WELFARE_FUND = "2500"


def money(value) -> str:
    return str(Decimal(value).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def col(key, label, kind="text"):
    return {"key": key, "label": label, "kind": kind}


def _signed(account_type, debit, credit) -> Decimal:
    return debit - credit if account_type in DEBIT_NORMAL_TYPES else credit - debit


def _totals_by_account(*, start=None, end=None) -> dict:
    """{account_id: (debit, credit)} for lines in the date range (inclusive)."""
    qs = JournalLine.objects.all()
    if start:
        qs = qs.filter(journal_entry__entry_date__gte=start)
    if end:
        qs = qs.filter(journal_entry__entry_date__lte=end)
    return {
        row["account_id"]: (row["d"] or ZERO, row["c"] or ZERO)
        for row in qs.values("account_id").annotate(d=Sum("debit"), c=Sum("credit"))
    }


def _balance(code, *, as_of=None) -> Decimal:
    account = Account.objects.filter(code=code).first()
    return account.balance(as_of=as_of) if account else ZERO


def _surplus(*, start=None, end=None) -> tuple[Decimal, Decimal]:
    totals = _totals_by_account(start=start, end=end)
    income = expense = ZERO
    for account in Account.objects.filter(account_type__in=[AccountType.INCOME, AccountType.EXPENSE]):
        d, c = totals.get(account.id, (ZERO, ZERO))
        if account.account_type == AccountType.INCOME:
            income += c - d
        else:
            expense += d - c
    return income, expense


# --- Financial statements ----------------------------------------------------


def trial_balance(*, as_of: date) -> dict:
    totals = _totals_by_account(end=as_of)
    rows = []
    total_dr = total_cr = ZERO
    for account in Account.objects.order_by("code"):
        d, c = totals.get(account.id, (ZERO, ZERO))
        net = d - c
        if net == 0 and not account.is_active:
            continue
        dr, cr = (net, ZERO) if net >= 0 else (ZERO, -net)
        total_dr += dr
        total_cr += cr
        rows.append([account.code, account.name, account.get_account_type_display(), money(dr), money(cr)])
    return {
        "title": _("Trial balance"),
        "period": _("As at %(date)s") % {"date": as_of.isoformat()},
        "summary": [],
        "sections": [{
            "title": _("Accounts"),
            "columns": [col("code", _("Code")), col("name", _("Account")), col("type", _("Type")),
                        col("debit", _("Debit"), "money"), col("credit", _("Credit"), "money")],
            "rows": rows,
            "totals": ["", _("Total"), "", money(total_dr), money(total_cr)],
        }],
        "checks": [{"label": _("Debits equal credits"), "ok": total_dr == total_cr,
                    "detail": f"{money(total_dr)} / {money(total_cr)}"}],
    }


def balance_sheet(*, as_of: date) -> dict:
    """Statement of financial position. There's no year-end closing entry
    yet, so all income less expenses to date is shown as accumulated surplus
    - which is what makes assets equal liabilities plus equity."""
    totals = _totals_by_account(end=as_of)
    groups = {AccountType.ASSET: [], AccountType.LIABILITY: [], AccountType.EQUITY: []}
    sums = defaultdict(lambda: ZERO)
    for account in Account.objects.filter(account_type__in=groups).order_by("code"):
        d, c = totals.get(account.id, (ZERO, ZERO))
        balance = _signed(account.account_type, d, c)
        if balance == 0 and not account.is_active:
            continue
        groups[account.account_type].append([account.code, account.name, money(balance)])
        sums[account.account_type] += balance
    income, expense = _surplus(end=as_of)
    surplus = income - expense
    groups[AccountType.EQUITY].append(["", _("Accumulated surplus / (deficit)"), money(surplus)])
    sums[AccountType.EQUITY] += surplus

    columns = [col("code", _("Code")), col("name", _("Account")), col("amount", _("Amount"), "money")]
    liabilities_and_equity = sums[AccountType.LIABILITY] + sums[AccountType.EQUITY]
    return {
        "title": _("Statement of financial position"),
        "period": _("As at %(date)s") % {"date": as_of.isoformat()},
        "summary": [
            {"label": _("Total assets"), "value": money(sums[AccountType.ASSET]), "kind": "money"},
            {"label": _("Total liabilities"), "value": money(sums[AccountType.LIABILITY]), "kind": "money"},
            {"label": _("Total equity"), "value": money(sums[AccountType.EQUITY]), "kind": "money"},
        ],
        "sections": [
            {"title": _("Assets"), "columns": columns, "rows": groups[AccountType.ASSET],
             "totals": ["", _("Total assets"), money(sums[AccountType.ASSET])]},
            {"title": _("Liabilities"), "columns": columns, "rows": groups[AccountType.LIABILITY],
             "totals": ["", _("Total liabilities"), money(sums[AccountType.LIABILITY])]},
            {"title": _("Equity"), "columns": columns, "rows": groups[AccountType.EQUITY],
             "totals": ["", _("Total equity"), money(sums[AccountType.EQUITY])]},
        ],
        "checks": [{"label": _("Assets equal liabilities plus equity"),
                    "ok": sums[AccountType.ASSET] == liabilities_and_equity,
                    "detail": f"{money(sums[AccountType.ASSET])} / {money(liabilities_and_equity)}"}],
    }


def income_statement(*, start: date, end: date) -> dict:
    totals = _totals_by_account(start=start, end=end)
    income_rows, expense_rows = [], []
    income = expense = ZERO
    for account in Account.objects.filter(account_type__in=[AccountType.INCOME, AccountType.EXPENSE]).order_by("code"):
        d, c = totals.get(account.id, (ZERO, ZERO))
        amount = _signed(account.account_type, d, c)
        if amount == 0 and not account.is_active:
            continue
        if account.account_type == AccountType.INCOME:
            income_rows.append([account.code, account.name, money(amount)])
            income += amount
        else:
            expense_rows.append([account.code, account.name, money(amount)])
            expense += amount
    columns = [col("code", _("Code")), col("name", _("Account")), col("amount", _("Amount"), "money")]
    return {
        "title": _("Income statement"),
        "period": f"{start.isoformat()} – {end.isoformat()}",
        "summary": [
            {"label": _("Total income"), "value": money(income), "kind": "money"},
            {"label": _("Total expenses"), "value": money(expense), "kind": "money"},
            {"label": _("Surplus / (deficit)"), "value": money(income - expense), "kind": "money"},
        ],
        "sections": [
            {"title": _("Income"), "columns": columns, "rows": income_rows, "totals": ["", _("Total income"), money(income)]},
            {"title": _("Expenses"), "columns": columns, "rows": expense_rows,
             "totals": ["", _("Total expenses"), money(expense)]},
        ],
        "checks": [],
    }


def general_ledger(*, account_code: str, start: date, end: date) -> dict:
    account = Account.objects.get(code=account_code)
    opening = account.balance(as_of=start - timedelta(days=1))
    lines = (
        JournalLine.objects.filter(account=account, journal_entry__entry_date__gte=start, journal_entry__entry_date__lte=end)
        .select_related("journal_entry", "journal_entry__created_by", "member")
        .order_by("journal_entry__entry_date", "journal_entry__created_at", "id")
    )
    running = opening
    rows = []
    total_dr = total_cr = ZERO
    for line in lines:
        running += _signed(account.account_type, line.debit, line.credit)
        total_dr += line.debit
        total_cr += line.credit
        entry = line.journal_entry
        rows.append([
            entry.entry_date.isoformat(), entry.reference, line.description or entry.description,
            line.member.member_number if line.member else "",
            money(line.debit), money(line.credit), money(running),
            entry.created_by.get_full_name() if entry.created_by else "",
        ])
    return {
        "title": _("General ledger: %(code)s %(name)s") % {"code": account.code, "name": account.name},
        "period": f"{start.isoformat()} – {end.isoformat()}",
        "summary": [
            {"label": _("Opening balance"), "value": money(opening), "kind": "money"},
            {"label": _("Closing balance"), "value": money(running), "kind": "money"},
        ],
        "sections": [{
            "title": _("Transactions"),
            "columns": [col("date", _("Date"), "date"), col("ref", _("Reference")), col("description", _("Description")),
                        col("member", _("Member")), col("debit", _("Debit"), "money"), col("credit", _("Credit"), "money"),
                        col("balance", _("Balance"), "money"), col("posted_by", _("Posted by"))],
            "rows": rows,
            "totals": ["", "", _("Total"), "", money(total_dr), money(total_cr), money(running), ""],
        }],
        "checks": [],
    }


def journal(*, start: date, end: date) -> dict:
    """The day book - every entry with who posted it and what it reverses."""
    entries = (
        JournalEntry.objects.filter(entry_date__gte=start, entry_date__lte=end)
        .select_related("created_by", "reverses", "reversed_by")
        .prefetch_related("lines__account", "lines__member")
        .order_by("entry_date", "created_at")
    )
    rows = []
    total = ZERO
    for entry in entries:
        for line in entry.lines.all():
            total += line.debit
            rows.append([
                entry.entry_date.isoformat(), entry.reference, entry.description,
                f"{line.account.code} {line.account.name}", line.member.member_number if line.member else "",
                money(line.debit), money(line.credit),
                entry.created_by.get_full_name() if entry.created_by else _("System"),
                entry.reverses.reference if entry.reverses_id else "",
                entry.reversed_by.reference if hasattr(entry, "reversed_by") else "",
            ])
    return {
        "title": _("Journal (day book)"),
        "period": f"{start.isoformat()} – {end.isoformat()}",
        "summary": [{"label": _("Entries"), "value": str(len(entries)), "kind": "number"}],
        "sections": [{
            "title": _("Entries"),
            "columns": [col("date", _("Date"), "date"), col("ref", _("Reference")), col("description", _("Description")),
                        col("account", _("Account")), col("member", _("Member")), col("debit", _("Debit"), "money"),
                        col("credit", _("Credit"), "money"), col("posted_by", _("Posted by")),
                        col("reverses", _("Reverses")), col("reversed_by", _("Reversed by"))],
            "rows": rows,
            "totals": ["", "", "", "", _("Total"), money(total), money(total), "", "", ""],
        }],
        "checks": [],
    }


# --- Member sub-ledgers --------------------------------------------------------


MEMBER_LEDGERS = [
    (SHARES, "shares"),
    (SAVINGS, "savings"),
    (LOANS, "loans"),
    (WELFARE_PREPAID, "welfare_balance"),
    (WELFARE_DUES, "welfare_owed"),
]


def member_balances(*, as_of: date) -> dict:
    """Every member's balance in each sub-ledger, and the reconciliation an
    auditor checks first: do the member balances add up to each control
    account in the general ledger?"""
    from members.models import Member

    accounts = {a.code: a for a in Account.objects.filter(code__in=[c for c, _k in MEMBER_LEDGERS])}
    per_member = defaultdict(lambda: defaultdict(lambda: ZERO))
    unallocated = defaultdict(lambda: ZERO)
    rows_q = (
        JournalLine.objects.filter(account__in=accounts.values(), journal_entry__entry_date__lte=as_of)
        .values("account__code", "account__account_type", "member_id")
        .annotate(d=Sum("debit"), c=Sum("credit"))
    )
    for r in rows_q:
        amount = _signed(r["account__account_type"], r["d"] or ZERO, r["c"] or ZERO)
        if r["member_id"] is None:
            unallocated[r["account__code"]] += amount
        else:
            per_member[r["member_id"]][r["account__code"]] += amount

    labels = {SHARES: _("Share capital"), SAVINGS: _("Savings"), LOANS: _("Loans"),
              WELFARE_PREPAID: _("Welfare balance"), WELFARE_DUES: _("Welfare owed")}
    member_totals = defaultdict(lambda: ZERO)
    rows = []
    for member in Member.objects.filter(pk__in=per_member.keys()).order_by("member_number"):
        balances = per_member[member.pk]
        values = []
        for code, _k in MEMBER_LEDGERS:
            member_totals[code] += balances[code]
            values.append(money(balances[code]))
        rows.append([member.member_number, member.full_name, member.get_status_display(), *values])

    checks = []
    for code, _k in MEMBER_LEDGERS:
        if code not in accounts:
            continue
        control = accounts[code].balance(as_of=as_of)
        ok = control == member_totals[code] and unallocated[code] == 0
        checks.append({
            "label": _("%(ledger)s: members total equals control account %(code)s") % {"ledger": labels[code], "code": code},
            "ok": ok,
            "detail": f"{money(member_totals[code])} / {money(control)}"
                      + (f" ({_('unallocated')} {money(unallocated[code])})" if unallocated[code] else ""),
        })
    return {
        "title": _("Member balances and control account reconciliation"),
        "period": _("As at %(date)s") % {"date": as_of.isoformat()},
        "summary": [{"label": labels[c], "value": money(member_totals[c]), "kind": "money"} for c, _k in MEMBER_LEDGERS],
        "sections": [{
            "title": _("Members"),
            "columns": [col("number", _("Member no.")), col("name", _("Name")), col("status", _("Status")),
                        *[col(k, labels[c], "money") for c, k in MEMBER_LEDGERS]],
            "rows": rows,
            "totals": ["", _("Total"), "", *[money(member_totals[c]) for c, _k in MEMBER_LEDGERS]],
        }],
        "checks": checks,
    }


# --- Loans ---------------------------------------------------------------------


BUCKETS = ["CURRENT", "1-30", "31-60", "61-90", "90+"]


def loan_portfolio(*, as_of: date) -> dict:
    """Outstanding loans with arrears ageing and portfolio at risk (PAR).
    Arrears are measured today, like the loan screens (loans.services.
    get_arrears_status); principal is reconciled to control account 4000."""
    from loans.models import Loan, LoanStatus
    from loans.services import get_arrears_status

    loans = (
        Loan.objects.filter(status__in=[LoanStatus.ACTIVE, LoanStatus.DEFAULTED])
        .select_related("member", "product").prefetch_related("schedule").order_by("member__member_number")
    )
    rows = []
    bucket_count = defaultdict(int)
    bucket_principal = defaultdict(lambda: ZERO)
    total_principal = total_interest = total_overdue = ZERO
    for loan in loans:
        schedule = list(loan.schedule.all())
        principal = sum((r.principal_due - r.principal_paid for r in schedule), ZERO)
        interest = sum((r.interest_due - r.interest_paid for r in schedule), ZERO)
        arrears = get_arrears_status(loan) if loan.status == LoanStatus.ACTIVE else {
            "days_overdue": "", "bucket": "90+", "amount_overdue": principal + interest}
        bucket = arrears["bucket"] if arrears["bucket"] in BUCKETS else "CURRENT"
        bucket_count[bucket] += 1
        bucket_principal[bucket] += principal
        total_principal += principal
        total_interest += interest
        total_overdue += arrears["amount_overdue"]
        rows.append([
            loan.member.member_number, loan.member.full_name, loan.product.name, loan.get_status_display(),
            loan.disbursed_at.date().isoformat() if loan.disbursed_at else "",
            money(loan.amount_requested), money(principal), money(interest),
            money(arrears["amount_overdue"]), str(arrears["days_overdue"]), bucket,
        ])

    at_risk = sum((bucket_principal[b] for b in ("31-60", "61-90", "90+")), ZERO)
    par30 = (at_risk * 100 / total_principal).quantize(Decimal("0.01")) if total_principal else ZERO
    ledger_principal = _balance(LOANS, as_of=as_of)
    return {
        "title": _("Loan portfolio and arrears ageing"),
        "period": _("As at %(date)s") % {"date": as_of.isoformat()},
        "summary": [
            {"label": _("Loans outstanding"), "value": str(len(rows)), "kind": "number"},
            {"label": _("Principal outstanding"), "value": money(total_principal), "kind": "money"},
            {"label": _("Interest outstanding"), "value": money(total_interest), "kind": "money"},
            {"label": _("Amount in arrears"), "value": money(total_overdue), "kind": "money"},
            {"label": _("Portfolio at risk (>30 days)"), "value": str(par30), "kind": "percent"},
        ],
        "sections": [
            {
                "title": _("Ageing"),
                "columns": [col("bucket", _("Days overdue")), col("count", _("Loans"), "number"),
                            col("principal", _("Principal"), "money")],
                "rows": [[b, str(bucket_count[b]), money(bucket_principal[b])] for b in BUCKETS],
                "totals": [_("Total"), str(len(rows)), money(total_principal)],
            },
            {
                "title": _("Loans"),
                "columns": [col("number", _("Member no.")), col("name", _("Name")), col("product", _("Product")),
                            col("status", _("Status")), col("disbursed", _("Disbursed"), "date"),
                            col("amount", _("Amount"), "money"), col("principal", _("Principal due"), "money"),
                            col("interest", _("Interest due"), "money"), col("overdue", _("In arrears"), "money"),
                            col("days", _("Days overdue"), "number"), col("bucket", _("Bucket"))],
                "rows": rows,
                "totals": ["", _("Total"), "", "", "", "", money(total_principal), money(total_interest),
                           money(total_overdue), "", ""],
            },
        ],
        "checks": [{"label": _("Principal outstanding equals loans control account 4000"),
                    "ok": ledger_principal == total_principal,
                    "detail": f"{money(total_principal)} / {money(ledger_principal)}"}],
    }


# --- Cash-side registers -------------------------------------------------------


def collections(*, start: date, end: date) -> dict:
    """Mobile-money collections (M-Pesa / Selcom) in the period, by outcome."""
    from payments.models import PaymentCollection

    items = (
        PaymentCollection.objects.filter(created_at__date__gte=start, created_at__date__lte=end)
        .select_related("member").order_by("created_at")
    )
    rows = []
    by_status = defaultdict(lambda: [0, ZERO])
    for c in items:
        by_status[c.get_status_display()][0] += 1
        by_status[c.get_status_display()][1] += c.amount
        rows.append([
            c.created_at.date().isoformat(), c.member.member_number, c.member.full_name, c.get_purpose_display(),
            c.provider, c.phone_number, money(c.amount), c.get_status_display(), c.provider_receipt or c.provider_reference,
        ])
    received = sum((c.amount for c in items if c.status == "SUCCESS"), ZERO)
    return {
        "title": _("Mobile money collections"),
        "period": f"{start.isoformat()} – {end.isoformat()}",
        "summary": [
            {"label": _("Received"), "value": money(received), "kind": "money"},
            {"label": _("Requests"), "value": str(len(rows)), "kind": "number"},
        ],
        "sections": [
            {"title": _("By status"), "columns": [col("status", _("Status")), col("count", _("Count"), "number"),
                                                   col("amount", _("Amount"), "money")],
             "rows": [[s, str(n), money(a)] for s, (n, a) in sorted(by_status.items())], "totals": None},
            {"title": _("Collections"),
             "columns": [col("date", _("Date"), "date"), col("number", _("Member no.")), col("name", _("Name")),
                         col("purpose", _("Purpose")), col("provider", _("Provider")), col("phone", _("Phone")),
                         col("amount", _("Amount"), "money"), col("status", _("Status")), col("ref", _("Receipt"))],
             "rows": rows, "totals": None},
        ],
        "checks": [],
    }


def distribution_register(*, start: date, end: date) -> dict:
    """Dividends and interest declared in the period, with withholding tax."""
    from distributions.models import DistributionEntry, DistributionRunStatus

    entries = (
        DistributionEntry.objects.filter(
            run__status=DistributionRunStatus.APPROVED, run__period_end__gte=start, run__period_end__lte=end
        ).select_related("run", "member").order_by("run__period_end", "member__member_number")
    )
    rows = []
    gross = wht = net = ZERO
    for e in entries:
        gross += e.gross_amount
        wht += e.wht_amount
        net += e.net_amount
        rows.append([
            e.run.period_end.isoformat(), e.run.get_kind_display(), e.member.member_number, e.member.full_name,
            money(e.basis_balance), money(e.gross_amount), money(e.wht_amount), money(e.net_amount), e.get_status_display(),
        ])
    return {
        "title": _("Dividend and interest register"),
        "period": f"{start.isoformat()} – {end.isoformat()}",
        "summary": [
            {"label": _("Gross"), "value": money(gross), "kind": "money"},
            {"label": _("Withholding tax"), "value": money(wht), "kind": "money"},
            {"label": _("Net"), "value": money(net), "kind": "money"},
        ],
        "sections": [{
            "title": _("Entries"),
            "columns": [col("period", _("Period end"), "date"), col("kind", _("Kind")), col("number", _("Member no.")),
                        col("name", _("Name")), col("basis", _("Basis"), "money"), col("gross", _("Gross"), "money"),
                        col("wht", _("WHT"), "money"), col("net", _("Net"), "money"), col("status", _("Status"))],
            "rows": rows,
            "totals": ["", "", "", _("Total"), "", money(gross), money(wht), money(net), ""],
        }],
        "checks": [],
    }


# --- Dashboard / tasks -----------------------------------------------------------


def finance_summary() -> dict:
    from members.models import Member, MemberStatus
    from payments.models import PaymentCollection

    today = date.today()
    year_start = date(today.year, 1, 1)
    income, expense = _surplus(start=year_start, end=today)
    portfolio = loan_portfolio(as_of=today)
    par = next(s["value"] for s in portfolio["summary"] if s["kind"] == "percent")
    received_today = PaymentCollection.objects.filter(created_at__date=today, status="SUCCESS").aggregate(
        t=Sum("amount"))["t"] or ZERO
    tb = trial_balance(as_of=today)
    return {
        "as_of": today.isoformat(),
        "cash": money(_balance(CASH)),
        "savings": money(_balance(SAVINGS)),
        "share_capital": money(_balance(SHARES)),
        "loans_outstanding": money(_balance(LOANS)),
        "welfare_fund": money(_balance(WELFARE_FUND)),
        "income_ytd": money(income),
        "expenses_ytd": money(expense),
        "surplus_ytd": money(income - expense),
        "par30": par,
        "collections_today": money(received_today),
        "active_members": Member.objects.filter(status=MemberStatus.ACTIVE).count(),
        "ledger_balanced": tb["checks"][0]["ok"],
    }


def my_tasks(user) -> list[dict]:
    """What's waiting on this particular leader, by what their role allows."""
    from accesscontrol.permissions import user_has_permission
    from distributions.models import DistributionRun, DistributionRunStatus
    from loans.models import Loan, LoanStatus
    from welfare.models import WelfareCase, WelfareCaseStatus

    tasks = []

    def add(key, permission, count):
        if count and user_has_permission(user, permission):
            tasks.append({"key": key, "count": count})

    add("loans_to_appraise", "loans.appraise", Loan.objects.filter(status=LoanStatus.PENDING_APPRAISAL).count())
    add("loans_to_decide", "loans.approve", Loan.objects.filter(status=LoanStatus.APPRAISED).count())
    add("loans_to_disburse", "loans.disburse", Loan.objects.filter(status=LoanStatus.APPROVED).count())
    add("distributions_to_approve", "distributions.approve_distribution",
        DistributionRun.objects.filter(status=DistributionRunStatus.PENDING_APPROVAL).exclude(proposed_by=user).count())
    add("welfare_to_approve", "welfare.approve_case",
        WelfareCase.objects.filter(status=WelfareCaseStatus.PENDING_APPROVAL).exclude(created_by=user).count())

    from members.models import (
        ApplicationStatus,
        ChangeRequestStatus,
        InactivityFlag,
        MemberApplication,
        ProfileChangeRequest,
    )

    add("applications_to_approve", "members.approve_admission",
        MemberApplication.objects.filter(status=ApplicationStatus.PENDING).exclude(submitted_by=user).count())

    add("profile_changes_to_approve", "members.approve_changes",
        ProfileChangeRequest.objects.filter(status=ChangeRequestStatus.PENDING).exclude(member__user=user).count())
    add("members_to_archive", "members.approve_changes",
        InactivityFlag.objects.filter(status=InactivityFlag.PENDING).count())
    return tasks

