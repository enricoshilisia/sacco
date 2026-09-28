from datetime import date, timedelta
from decimal import Decimal as D

from django.utils import timezone
from django_tenants.test.cases import TenantTestCase

from accesscontrol.models import Membership, Role
from accounting.models import Account
from configuration.models import TenantConfig
from fines.models import OffenceType
from fines.services import charge_fine
from identity.models import TenantAccess, User
from savings.services import contribute_shares

from . import exit_services
from .models import Member, MembershipSettings, MemberStatus, ResignationStatus


class ResignationTests(TenantTestCase):
    """Three months' notice, 90% back, less anything still owed."""

    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        config = TenantConfig.get_solo()
        config.monthly_contribution_target = TenantConfig.MONTHLY_TO_SHARES
        config.withdrawals_enabled = False
        config.save()
        settings = MembershipSettings.get_solo()
        settings.notice_months = 3
        settings.exit_refund_percent = D("90")
        settings.exit_deducts_debts = True
        settings.save()
        self.member = Member.objects.create(member_number="IW-26-00001", first_name="Sandra", last_name="K",
                                            id_type="NATIONAL_ID", id_number="1", phone_number="")
        self.chair = self._user("+254711333001", "Chairperson")
        self.treasurer = self._user("+254711333002", "Treasurer")
        contribute_shares(member=self.member, amount=D("10000"), transaction_date=date(2026, 4, 18))

    def _user(self, phone, role):
        user = User.objects.create_user(phone_number=phone, password="pass12345", first_name=role)
        TenantAccess.objects.create(user=user, tenant=self.tenant)
        Membership.objects.create(user=user, role=Role.objects.get(name=role))
        return user

    def test_notice_runs_three_months_and_pays_ninety_percent(self):
        given = date(2026, 6, 10)
        resignation = exit_services.give_notice(member=self.member, reason="Moving away", on=given)
        self.assertEqual(resignation.leaving_on, date(2026, 9, 10))

        with self.assertRaisesMessage(ValueError, "approved first"):
            exit_services.pay_refund(resignation=resignation, by=self.treasurer, on=date(2026, 9, 11))
        exit_services.decide_notice(resignation=resignation, approve=True, by=self.chair)
        self.member.refresh_from_db()
        self.assertEqual(self.member.status, MemberStatus.NOTICE)

        with self.assertRaisesMessage(ValueError, "No refund before then"):
            exit_services.pay_refund(resignation=resignation, by=self.treasurer, on=date(2026, 8, 1))

        exit_services.pay_refund(resignation=resignation, by=self.treasurer, on=date(2026, 9, 11))
        resignation.refresh_from_db()
        self.member.refresh_from_db()
        self.assertEqual(resignation.status, ResignationStatus.PAID)
        self.assertEqual(resignation.refund_paid, D("9000.00"))
        self.assertEqual(resignation.retained_by_group, D("1000.00"))
        self.assertEqual(self.member.status, MemberStatus.EXITED)
        # The books: their savings are gone, the group kept 10%.
        self.assertEqual(Account.objects.get(code="3000").balance(member=self.member), D("0"))
        self.assertEqual(Account.objects.get(code="5300").balance(), D("1000.00"))
        entry = resignation.journal_entry
        self.assertEqual(sum(l.debit for l in entry.lines.all()), sum(l.credit for l in entry.lines.all()))

    def test_debts_come_out_of_the_refund(self):
        offence = OffenceType.objects.create(name="Absent", amount=D("100"))
        charge_fine(member=self.member, offence_type=offence, amount=D("1500"), incurred_on=date(2026, 5, 1))
        quote = exit_services.exit_quote(self.member)
        self.assertEqual(quote["refundable"], D("9000.00"))
        self.assertEqual(quote["debts"], D("1500.00"))
        self.assertEqual(quote["payable"], D("7500.00"))

        resignation = exit_services.give_notice(member=self.member, on=date(2026, 6, 10))
        exit_services.decide_notice(resignation=resignation, approve=True, by=self.chair)
        exit_services.pay_refund(resignation=resignation, by=self.treasurer, on=date(2026, 9, 11))
        resignation.refresh_from_db()
        self.assertEqual(resignation.refund_paid, D("7500.00"))
        self.assertEqual(Account.objects.get(code="1400").balance(member=self.member), D("0"))

    def test_nobody_decides_or_pays_their_own_notice(self):
        self.member.user = self.chair
        self.member.save(update_fields=["user"])
        resignation = exit_services.give_notice(member=self.member, on=date(2026, 6, 10), by=self.chair)
        with self.assertRaisesMessage(ValueError, "someone else"):
            exit_services.decide_notice(resignation=resignation, approve=True, by=self.chair)

    def test_a_member_can_change_their_mind(self):
        resignation = exit_services.give_notice(member=self.member, on=date(2026, 6, 10))
        exit_services.decide_notice(resignation=resignation, approve=True, by=self.chair)
        exit_services.cancel_notice(resignation=resignation, by=self.chair, reason="Stayed")
        self.member.refresh_from_db()
        self.assertEqual(self.member.status, MemberStatus.ACTIVE)


class SuspensionTests(TenantTestCase):
    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        self.member = Member.objects.create(member_number="IW-26-00002", first_name="Brian", last_name="R",
                                            id_type="NATIONAL_ID", id_number="2", phone_number="")

    def test_suspension_blocks_welfare_and_lifts_itself(self):
        from welfare.models import WelfareCaseType
        from welfare.services import create_case

        exit_services.suspend(member=self.member, days=90, reason="Defamation in the group")
        self.member.refresh_from_db()
        self.assertEqual(self.member.status, MemberStatus.SUSPENDED)
        self.assertEqual(self.member.suspended_until, date.today() + timedelta(days=90))

        case_type = WelfareCaseType.objects.create(name="Sickness", contribution_per_member=D("100"))
        with self.assertRaisesMessage(ValueError, "suspended"):
            create_case(case_type=case_type, beneficiary=self.member)

        # Once the time is served, the monthly check puts them back.
        self.member.suspended_until = date.today() - timedelta(days=1)
        self.member.save(update_fields=["suspended_until"])
        self.assertEqual(exit_services.lift_expired_suspensions(), 1)
        self.member.refresh_from_db()
        self.assertEqual(self.member.status, MemberStatus.ACTIVE)

    def test_probation_waits_out_the_ninety_days(self):
        from .admission import verification_status

        settings = MembershipSettings.get_solo()
        settings.probation_days = 90
        settings.save()
        status = verification_status(self.member)
        self.assertEqual(status["days_left"], 90)
        self.assertFalse(status["verified"] and status["days_left"] == 0)


class ApologyDeadlineTests(TenantTestCase):
    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def test_apologies_close_three_days_before_a_physical_meeting(self):
        from governance.models import Meeting
        from governance.services import send_apology
        from members.models import MemberActivitySettings

        settings = MemberActivitySettings.get_solo()
        settings.apology_days_before_physical = 3
        settings.apology_hours_before_online = 3
        settings.save()
        member = Member.objects.create(member_number="IW-26-00003", first_name="Tecla", last_name="M",
                                       id_type="NATIONAL_ID", id_number="3", phone_number="")

        soon = Meeting.objects.create(meeting_type="MONTHLY", title="Tomorrow",
                                      scheduled_at=timezone.now() + timedelta(days=1))
        with self.assertRaisesMessage(ValueError, "closed"):
            send_apology(meeting=soon, member=member, reason="Travelling")

        later = Meeting.objects.create(meeting_type="MONTHLY", title="Next week",
                                       scheduled_at=timezone.now() + timedelta(days=7))
        self.assertEqual(send_apology(meeting=later, member=member, reason="Travelling").status, "APOLOGY")

        online = Meeting.objects.create(meeting_type="MONTHLY", title="Online tomorrow", is_online=True,
                                        scheduled_at=timezone.now() + timedelta(days=1))
        self.assertEqual(send_apology(meeting=online, member=member, reason="Network").status, "APOLOGY")
