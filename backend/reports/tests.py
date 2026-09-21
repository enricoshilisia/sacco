from datetime import date
from decimal import Decimal
from unittest import mock

from django_tenants.test.cases import TenantTestCase
from django_tenants.test.client import TenantClient

from accesscontrol.models import Membership, Role
from accounting.models import Account
from distributions.services import approve_distribution_run, propose_dividend_run
from identity.models import User
from loans.models import InterestMethod, Loan, LoanProduct, LoanStatus
from loans.services import disburse_to_savings, record_loan_repayment
from members.models import Member
from savings.models import SavingsProduct
from savings.services import contribute_shares, deposit_savings, get_or_open_savings_account
from welfare.models import WelfarePaymentMethod
from welfare.services import record_payment

from . import services

D = Decimal
TODAY = date.today()
YEAR_START = date(TODAY.year, 1, 1)


class ReportsTestBase(TenantTestCase):
    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        sms = mock.patch("notifications.tasks.send_notification_task.delay")
        sms.start()
        self.addCleanup(sms.stop)
        self.client = TenantClient(self.tenant)
        self.treasurer = self._user("+254700000301", "Treasurer")
        self.auditor = self._user("+254700000302", "Auditor")
        self.teller = self._user("+254700000303", "Teller")
        self.alice = self._member("M-00001")
        self.bob = self._member("M-00002")
        self._build_books()

    def _user(self, phone, role):
        user = User.objects.create_user(phone_number=phone, password="pass12345", first_name=role)
        Membership.objects.create(user=user, role=Role.objects.get(name=role))
        return user

    def _member(self, number):
        return Member.objects.create(
            member_number=number, first_name="Mem", last_name=number, id_type="NATIONAL_ID",
            id_number=number, phone_number="+254711000000",
        )

    def _build_books(self):
        """A small but realistic set of books, all posted through the real
        services: shares, deposits, a loan disbursed and part-repaid, welfare."""
        self.savings_product = SavingsProduct.objects.create(name="Ordinary", code="ord", product_type="VOLUNTARY")
        contribute_shares(member=self.alice, amount=D("5000"), transaction_date=TODAY)
        contribute_shares(member=self.bob, amount=D("3000"), transaction_date=TODAY)
        deposit_savings(savings_account=get_or_open_savings_account(self.alice, self.savings_product),
                        amount=D("20000"), transaction_date=TODAY)
        record_payment(member=self.bob, amount=D("1000"), method=WelfarePaymentMethod.CASH, transaction_date=TODAY)

        product = LoanProduct.objects.create(
            name="Development", code="dev", interest_method=InterestMethod.REDUCING_BALANCE,
            interest_rate=D("0.1200"), max_term_months=12, requires_guarantors=False,
        )
        self.loan = Loan.objects.create(
            member=self.alice, product=product, amount_requested=D("12000"), term_months=12,
            interest_method=product.interest_method, interest_rate=product.interest_rate, status=LoanStatus.APPROVED,
        )
        disburse_to_savings(loan=self.loan, product=self.savings_product)
        record_loan_repayment(loan=self.loan, amount=D("1500"), transaction_date=TODAY)


class FinancialStatementTests(ReportsTestBase):
    def test_trial_balance_balances(self):
        report = services.trial_balance(as_of=TODAY)
        self.assertTrue(report["checks"][0]["ok"], report["checks"])

    def test_balance_sheet_balances_including_surplus(self):
        report = services.balance_sheet(as_of=TODAY)
        self.assertTrue(report["checks"][0]["ok"], report["checks"])

    def test_income_statement_shows_loan_interest(self):
        interest_income = Account.objects.get(code="5000").balance()
        self.assertGreater(interest_income, 0)
        report = services.income_statement(start=YEAR_START, end=TODAY)
        surplus = next(s["value"] for s in report["summary"] if s["label"] == "Surplus / (deficit)")
        self.assertEqual(D(surplus), interest_income)

    def test_general_ledger_running_balance_ends_at_account_balance(self):
        report = services.general_ledger(account_code="1000", start=YEAR_START, end=TODAY)
        closing = report["summary"][1]["value"]
        self.assertEqual(D(closing), Account.objects.get(code="1000").balance())


class ReconciliationTests(ReportsTestBase):
    def test_member_balances_reconcile_to_every_control_account(self):
        report = services.member_balances(as_of=TODAY)
        self.assertTrue(report["checks"])
        for check in report["checks"]:
            self.assertTrue(check["ok"], check)

    def test_loan_portfolio_principal_matches_ledger(self):
        report = services.loan_portfolio(as_of=TODAY)
        self.assertTrue(report["checks"][0]["ok"], report["checks"])
        self.assertEqual(report["sections"][1]["rows"][0][0], "M-00001")
        par = next(s["value"] for s in report["summary"] if s["kind"] == "percent")
        self.assertEqual(D(par), D("0"))


class ManualJournalTests(ReportsTestBase):
    def setUp(self):
        super().setUp()
        self.client.force_login(self.treasurer)

    def test_treasurer_adds_expense_account_and_posts_a_balanced_expense(self):
        response = self.client.post("/api/accounting/accounts/", {"code": "6200", "name": "Rent", "account_type": "EXPENSE"},
                                    content_type="application/json")
        self.assertEqual(response.status_code, 201, response.content)
        rent = response.json()["id"]
        cash = str(Account.objects.get(code="1000").id)
        response = self.client.post("/api/accounting/journal-entries/", {
            "description": "Office rent September", "entry_date": TODAY.isoformat(),
            "lines": [{"account": rent, "debit": "2500.00"}, {"account": cash, "credit": "2500.00"}],
        }, content_type="application/json")
        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(Account.objects.get(code="6200").balance(), D("2500"))
        self.assertTrue(services.balance_sheet(as_of=TODAY)["checks"][0]["ok"])

    def test_unbalanced_manual_journal_is_refused(self):
        cash = str(Account.objects.get(code="1000").id)
        income = str(Account.objects.get(code="5000").id)
        response = self.client.post("/api/accounting/journal-entries/", {
            "description": "Bad", "entry_date": TODAY.isoformat(),
            "lines": [{"account": cash, "debit": "100.00"}, {"account": income, "credit": "90.00"}],
        }, content_type="application/json")
        self.assertEqual(response.status_code, 400)

    def test_member_control_accounts_are_blocked_from_manual_journals(self):
        savings = str(Account.objects.get(code="2000").id)
        cash = str(Account.objects.get(code="1000").id)
        response = self.client.post("/api/accounting/journal-entries/", {
            "description": "Sneaky", "entry_date": TODAY.isoformat(),
            "lines": [{"account": cash, "debit": "100.00"}, {"account": savings, "credit": "100.00"}],
        }, content_type="application/json")
        self.assertEqual(response.status_code, 400)
        self.assertIn("control accounts", str(response.json()))


class AccessTests(ReportsTestBase):
    def test_teller_cannot_see_member_balances_or_financial_statements(self):
        self.client.force_login(self.teller)
        self.assertEqual(self.client.get("/api/reports/member_balances/").status_code, 403)
        self.assertEqual(self.client.get("/api/reports/balance_sheet/").status_code, 403)
        keys = {r["key"] for r in self.client.get("/api/reports/").json()["reports"]}
        self.assertNotIn("member_balances", keys)

    def test_treasurer_sees_every_report(self):
        self.client.force_login(self.treasurer)
        catalog = self.client.get("/api/reports/").json()
        self.assertTrue(catalog["can_export"])
        self.assertEqual({r["key"] for r in catalog["reports"]}, set(__import__("reports.views").views.REPORTS))
        response = self.client.get(f"/api/reports/income_statement/?start={YEAR_START}&end={TODAY}")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.client.get("/api/reports/summary/").json()["ledger_balanced"], True)

    def test_auditor_exports_csv_with_audit_header(self):
        self.client.force_login(self.auditor)
        response = self.client.get("/api/reports/trial_balance/?export=csv")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "text/csv; charset=utf-8")
        body = response.content.decode("utf-8-sig")
        self.assertIn("Test SACCO", body)
        self.assertIn("Trial balance", body)
        self.assertIn("Debits equal credits,OK", body)

    def test_bad_dates_are_a_400_not_a_crash(self):
        self.client.force_login(self.treasurer)
        self.assertEqual(self.client.get("/api/reports/journal/?start=2026-13-01").status_code, 400)
        self.assertEqual(self.client.get(f"/api/reports/journal/?start={TODAY}&end={YEAR_START.replace(year=TODAY.year - 1)}").status_code, 400)


class TaskAndApprovalTests(ReportsTestBase):
    def test_treasurer_cannot_approve_own_dividend_run(self):
        run = propose_dividend_run(period_start=YEAR_START, period_end=TODAY, rate=D("0.10"), created_by=self.treasurer)
        with self.assertRaises(ValueError):
            approve_distribution_run(run, approved_by=self.treasurer)

    def test_my_tasks_counts_loans_waiting_for_disbursement(self):
        Loan.objects.create(
            member=self.bob, product=self.loan.product, amount_requested=D("1000"), term_months=6,
            interest_method=self.loan.interest_method, interest_rate=self.loan.interest_rate, status=LoanStatus.APPROVED,
        )
        tasks = {t["key"]: t["count"] for t in services.my_tasks(self.treasurer)}
        self.assertEqual(tasks.get("loans_to_disburse"), 1)
        self.assertNotIn("loans_to_disburse", {t["key"] for t in services.my_tasks(self.teller)})
