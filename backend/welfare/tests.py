from datetime import date
from decimal import Decimal
from unittest import mock

from django.db.models import Sum
from django_tenants.test.cases import TenantTestCase
from django_tenants.test.client import TenantClient

from accesscontrol.models import Membership, Role
from accounting.models import Account, JournalLine
from identity.models import User
from members.models import Member, MemberStatus
from payments.models import CollectionPurpose, PaymentCollection
from payments.services import handle_collection_callback

from . import services
from .models import WelfareCaseStatus, WelfareCaseType, WelfareContribution, WelfarePayment, WelfarePaymentMethod

D = Decimal
TODAY = date.today()


class WelfareTestBase(TenantTestCase):
    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        sms = mock.patch("welfare.services.queue_sms")
        self.queue_sms = sms.start()
        self.addCleanup(sms.stop)

        self.manager = self._user("+254700000201", "WelfareManager")
        self.treasurer = self._user("+254700000202", "Treasurer")
        self.sick = self._member("M-00001")
        self.rich = self._member("M-00002")
        self.short = self._member("M-00003")
        self.broke = self._member("M-00004")
        self.dormant = self._member("M-00005", status=MemberStatus.DORMANT)
        self.sick_type = WelfareCaseType.objects.create(name="Member sick", contribution_per_member=D("200.00"))

    def _user(self, phone, role_name):
        user = User.objects.create_user(phone_number=phone, password="pass12345", first_name=role_name)
        Membership.objects.create(user=user, role=Role.objects.get(name=role_name))
        return user

    def _member(self, number, status=MemberStatus.ACTIVE, user=None):
        return Member.objects.create(
            member_number=number, user=user, status=status, first_name="Mem", last_name=number,
            id_type="NATIONAL_ID", id_number=number, phone_number="+254711000000",
        )

    def _pay(self, member, amount, on=TODAY):
        return services.record_payment(
            member=member, amount=D(amount), method=WelfarePaymentMethod.CASH, transaction_date=on
        )

    def _approved_case(self, case_type=None, beneficiary=None):
        case = services.create_case(
            case_type=case_type or self.sick_type, beneficiary=beneficiary or self.sick, created_by=self.manager
        )
        return services.approve_case(case, approved_by=self.treasurer)

    def _balance(self, code, member=None):
        return Account.objects.get(code=code).balance(member=member)

    def assertLedgerConsistent(self):
        """Debits == credits overall, and every member's dues on the ledger
        equal what their contribution records say they still owe."""
        totals = JournalLine.objects.aggregate(d=Sum("debit"), c=Sum("credit"))
        self.assertEqual(totals["d"], totals["c"])
        for member in Member.objects.all():
            outstanding = sum((c.outstanding for c in WelfareContribution.objects.filter(member=member)), D("0"))
            self.assertEqual(self._balance(services.WELFARE_DUES_RECEIVABLE_CODE, member), outstanding, member)


class LevyTests(WelfareTestBase):
    def test_levy_uses_balance_first_then_owes_the_rest(self):
        self._pay(self.rich, "1000")
        self._pay(self.short, "150")
        case = self._approved_case()

        self.assertEqual(services.levy_members(case), 3)  # rich, short, broke

        def contribution(member):
            return WelfareContribution.objects.get(case=case, member=member)

        self.assertEqual((contribution(self.rich).from_balance, contribution(self.rich).owed), (D("200"), D("0")))
        self.assertEqual((contribution(self.short).from_balance, contribution(self.short).owed), (D("150"), D("50")))
        self.assertEqual((contribution(self.broke).from_balance, contribution(self.broke).owed), (D("0"), D("200")))
        self.assertEqual(services.welfare_balance(self.rich), D("800"))
        self.assertEqual(services.welfare_balance(self.short), D("0"))
        self.assertEqual(services.welfare_owed(self.short), D("50"))
        self.assertEqual(services.welfare_owed(self.broke), D("200"))
        self.assertEqual(self._balance(services.WELFARE_FUND_CODE), D("600"))
        # Collected so far = what came out of balances (200 + 150).
        self.assertEqual(services.case_collected(case), D("350"))
        self.assertLedgerConsistent()

    def test_beneficiary_and_inactive_members_are_not_levied(self):
        case = self._approved_case()
        services.levy_members(case)
        levied = set(WelfareContribution.objects.filter(case=case).values_list("member__member_number", flat=True))
        self.assertEqual(levied, {"M-00002", "M-00003", "M-00004"})

    def test_beneficiary_contributes_when_the_rule_says_so(self):
        funeral = WelfareCaseType.objects.create(
            name="Death of parent", contribution_per_member=D("300"), beneficiary_contributes=True
        )
        case = self._approved_case(case_type=funeral)
        services.levy_members(case)
        self.assertTrue(WelfareContribution.objects.filter(case=case, member=self.sick).exists())

    def test_rerunning_the_levy_never_charges_twice(self):
        self._pay(self.rich, "1000")
        case = self._approved_case()
        services.levy_members(case)
        self.assertEqual(services.levy_members(case), 0)
        self.assertEqual(WelfareContribution.objects.filter(case=case).count(), 3)
        self.assertEqual(services.welfare_balance(self.rich), D("800"))
        self.assertEqual(self._balance(services.WELFARE_FUND_CODE), D("600"))
        self.assertLedgerConsistent()

    def test_rule_change_after_opening_does_not_change_the_case(self):
        case = services.create_case(case_type=self.sick_type, beneficiary=self.sick, created_by=self.manager)
        self.sick_type.contribution_per_member = D("999")
        self.sick_type.save()
        services.approve_case(case, approved_by=self.treasurer)
        services.levy_members(case)
        self.assertEqual(WelfareContribution.objects.get(case=case, member=self.broke).amount, D("200"))

    def test_levy_notifies_each_member(self):
        case = self._approved_case()
        with self.captureOnCommitCallbacks(execute=True):
            services.levy_members(case)
        self.assertEqual(self.queue_sms.call_count, 3)


class ApprovalTests(WelfareTestBase):
    def test_creator_cannot_approve_own_case(self):
        case = services.create_case(case_type=self.sick_type, beneficiary=self.sick, created_by=self.treasurer)
        with self.assertRaises(ValueError):
            services.approve_case(case, approved_by=self.treasurer)

    def test_rejected_case_levies_nobody(self):
        case = services.create_case(case_type=self.sick_type, beneficiary=self.sick, created_by=self.manager)
        services.reject_case(case, rejected_by=self.treasurer, notes="Not covered by constitution")
        with self.assertRaises(ValueError):
            services.levy_members(case)
        self.assertFalse(WelfareContribution.objects.exists())

    def test_inactive_rule_cannot_open_a_case(self):
        self.sick_type.is_active = False
        self.sick_type.save()
        with self.assertRaises(ValueError):
            services.create_case(case_type=self.sick_type, beneficiary=self.sick, created_by=self.manager)


class PaymentTests(WelfareTestBase):
    def test_payment_clears_oldest_dues_first_then_tops_up_balance(self):
        first = self._approved_case()
        services.levy_members(first)
        funeral = WelfareCaseType.objects.create(name="Death of member", contribution_per_member=D("300"))
        second = self._approved_case(case_type=funeral, beneficiary=self.rich)
        services.levy_members(second)
        self.assertEqual(services.welfare_owed(self.broke), D("500"))

        payment = self._pay(self.broke, "250")
        self.assertEqual((payment.applied_to_dues, payment.to_balance), (D("250"), D("0")))
        self.assertEqual(WelfareContribution.objects.get(case=first, member=self.broke).paid, D("200"))
        self.assertEqual(WelfareContribution.objects.get(case=second, member=self.broke).paid, D("50"))

        payment = self._pay(self.broke, "400")
        self.assertEqual((payment.applied_to_dues, payment.to_balance), (D("250"), D("150")))
        self.assertEqual(services.welfare_owed(self.broke), D("0"))
        self.assertEqual(services.welfare_balance(self.broke), D("150"))
        self.assertLedgerConsistent()

    def test_paid_dues_count_towards_the_case_collection(self):
        case = self._approved_case()
        services.levy_members(case)
        self.assertEqual(services.case_collected(case), D("0"))
        self._pay(self.broke, "200")
        self.assertEqual(services.case_collected(case), D("200"))

    def test_mobile_money_callback_records_welfare_payment_once(self):
        case = self._approved_case()
        services.levy_members(case)
        PaymentCollection.objects.create(
            idempotency_key="k1", member=self.broke, purpose=CollectionPurpose.WELFARE_CONTRIBUTION,
            provider="mock", provider_reference="ref-1", phone_number="+254711000000", amount=D("1200.00"),
        )
        for _ in range(2):  # providers redeliver callbacks
            handle_collection_callback(provider_code="mock", provider_reference="ref-1", success=True, receipt="R1")

        self.assertEqual(WelfarePayment.objects.filter(member=self.broke).count(), 1)
        self.assertEqual(services.welfare_owed(self.broke), D("0"))
        self.assertEqual(services.welfare_balance(self.broke), D("1000"))
        self.assertLedgerConsistent()


class PayoutTests(WelfareTestBase):
    def test_payout_is_capped_at_what_the_case_collected(self):
        self._pay(self.rich, "1000")
        case = self._approved_case()
        services.levy_members(case)  # collected: 200 from rich's balance

        with self.assertRaises(ValueError):
            services.record_payout(case=case, amount=D("200.01"), method="CASH", paid_on=TODAY)

        services.record_payout(case=case, amount=D("200"), method="CASH", paid_on=TODAY, paid_to="Mem M-00001")
        self.assertEqual(self._balance(services.WELFARE_FUND_CODE), D("400"))  # 600 levied - 200 paid

        self._pay(self.broke, "200")  # more collected -> can pay more
        services.record_payout(case=case, amount=D("200"), method="BANK", paid_on=TODAY)
        with self.assertRaises(ValueError):
            services.record_payout(case=case, amount=D("1"), method="CASH", paid_on=TODAY)
        self.assertLedgerConsistent()

    def test_no_payout_on_closed_or_pending_case(self):
        pending = services.create_case(case_type=self.sick_type, beneficiary=self.sick, created_by=self.manager)
        with self.assertRaises(ValueError):
            services.record_payout(case=pending, amount=D("1"), method="CASH", paid_on=TODAY)
        case = self._approved_case()
        services.close_case(case)
        with self.assertRaises(ValueError):
            services.record_payout(case=case, amount=D("1"), method="CASH", paid_on=TODAY)


class YearCloseTests(WelfareTestBase):
    def test_unused_balance_goes_to_fund_but_new_year_money_stays(self):
        last_year = TODAY.year - 1
        self._pay(self.rich, "1000", on=date(last_year, 3, 1))
        self._pay(self.rich, "500")  # this year's contribution
        case = self._approved_case()
        services.levy_members(case)  # 200 levied this year, from last year's leftover first

        year_close = services.start_year_close(year=last_year, closed_by=self.treasurer)
        services.run_year_close(year_close)

        self.assertEqual(year_close.sweeps.get(member=self.rich).amount, D("800"))
        self.assertEqual(services.welfare_balance(self.rich), D("500"))
        self.assertEqual(self._balance(services.WELFARE_FUND_CODE), D("600") + D("800"))
        self.assertLedgerConsistent()

        # Retry-safe, and a closed year can't be closed again.
        self.assertEqual(services.run_year_close(year_close), 0)
        with self.assertRaises(ValueError):
            services.start_year_close(year=last_year)

    def test_cannot_close_the_current_year(self):
        with self.assertRaises(ValueError):
            services.start_year_close(year=TODAY.year)


class WelfareApiTests(WelfareTestBase):
    def setUp(self):
        super().setUp()
        self.client = TenantClient(self.tenant)

    def test_member_sees_own_welfare(self):
        user = User.objects.create_user(phone_number="+254700000299", password="pass12345")
        self.broke.user = user
        self.broke.save()
        case = self._approved_case()
        services.levy_members(case)
        self.client.force_login(user)
        response = self.client.get("/api/welfare/me/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["summary"]["owed"], "200.00")
        self.assertEqual(response.json()["contributions"][0]["outstanding"], "200.00")

    def test_plain_member_cannot_see_all_cases(self):
        user = User.objects.create_user(phone_number="+254700000298", password="pass12345")
        Membership.objects.create(user=user, role=Role.objects.get(name="Member"))
        self.client.force_login(user)
        self.assertEqual(self.client.get("/api/welfare/cases/").status_code, 403)

    def test_manager_opens_and_treasurer_approves_which_queues_the_levy(self):
        self.client.force_login(self.manager)
        response = self.client.post(
            "/api/welfare/cases/",
            {"case_type": str(self.sick_type.id), "beneficiary": str(self.sick.id), "affected_person": "self"},
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        case_id = response.json()["id"]
        self.assertEqual(response.json()["contribution_per_member"], "200.00")

        # The manager doesn't hold welfare.approve_case.
        self.assertEqual(self.client.post(f"/api/welfare/cases/{case_id}/approve/").status_code, 403)

        self.client.force_login(self.treasurer)
        with mock.patch("welfare.views.levy_welfare_case_task.delay") as delay:
            with self.captureOnCommitCallbacks(execute=True):
                response = self.client.post(f"/api/welfare/cases/{case_id}/approve/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], WelfareCaseStatus.APPROVED)
        delay.assert_called_once()

    def test_counter_payment_endpoint(self):
        self.client.force_login(self.manager)
        response = self.client.post(
            f"/api/welfare/members/{self.broke.id}/payments/",
            {"amount": "1000.00", "method": "CASH", "transaction_date": TODAY.isoformat()},
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["summary"]["balance"], "1000.00")
