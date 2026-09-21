from datetime import date, datetime, timedelta
from decimal import Decimal
from unittest import mock

from django.utils import timezone
from django_tenants.test.cases import TenantTestCase
from django_tenants.test.client import TenantClient

from accesscontrol.models import Membership, Role
from governance import services as meetings
from governance.models import AttendanceStatus, Meeting, MeetingAttendance, MeetingStatus
from identity.models import User
from savings.models import SavingsProduct
from savings.services import deposit_savings, get_or_open_savings_account

from . import activity
from .models import InactivityFlag, Member, MemberActivitySettings, MemberStatusChange

D = Decimal


def months_ago(n, day=15):
    """A date in the calendar month n months before this one."""
    d = date.today().replace(day=1)
    for _ in range(n):
        d = (d - timedelta(days=1)).replace(day=1)
    return d.replace(day=min(day, 28))


class ActivityTestBase(TenantTestCase):
    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        sms = mock.patch("notifications.tasks.send_notification_task.delay")
        self.sms = sms.start()
        self.addCleanup(sms.stop)
        self.mandatory = SavingsProduct.objects.create(name="Monthly", code="monthly", product_type="MANDATORY_MONTHLY")
        self.voluntary = SavingsProduct.objects.create(name="Voluntary", code="vol", product_type="VOLUNTARY")
        self.user = User.objects.create_user(phone_number="+254711888001", password="pass12345")
        Membership.objects.create(user=self.user, role=Role.objects.get(name="Member"))
        self.member = self._member("M-00001", joined=months_ago(8), user=self.user)
        self.secretary = User.objects.create_user(phone_number="+254711888002", password="pass12345")
        Membership.objects.create(user=self.secretary, role=Role.objects.get(name="Secretary"))

    def _member(self, number, joined, user=None):
        member = Member.objects.create(
            member_number=number, user=user, first_name="Mem", last_name=number, id_type="NATIONAL_ID",
            id_number=number, phone_number="+254711000000",
        )
        Member.objects.filter(pk=member.pk).update(date_joined=joined)
        member.refresh_from_db()
        return member

    def _pay(self, member, on, amount="500", product=None):
        deposit_savings(savings_account=get_or_open_savings_account(member, product or self.mandatory),
                        amount=D(amount), transaction_date=on)

    def _held_meeting(self, days_ago):
        return Meeting.objects.create(
            meeting_type="MONTHLY", title=f"Meeting {days_ago}", status=MeetingStatus.HELD,
            scheduled_at=timezone.now() - timedelta(days=days_ago),
        )


class ContributionRuleTests(ActivityTestBase):
    def test_counts_consecutive_months_without_mandatory_savings(self):
        self._pay(self.member, months_ago(4))
        self.assertEqual(activity.missed_contribution_months(self.member), 3)

    def test_current_month_never_counts_and_voluntary_savings_do_not_help(self):
        self._pay(self.member, months_ago(1))
        self._pay(self.member, months_ago(2), product=self.voluntary)
        self.assertEqual(activity.missed_contribution_months(self.member), 0)
        self._pay(self.member, date.today(), product=self.voluntary)
        self.assertEqual(activity.missed_contribution_months(self.member), 0)

    def test_months_before_joining_do_not_count(self):
        newcomer = self._member("M-00002", joined=months_ago(1))
        self.assertEqual(activity.missed_contribution_months(newcomer), 1)

    def test_minimum_amount(self):
        settings = MemberActivitySettings.get_solo()
        settings.min_monthly_contribution = D("1000")
        settings.save()
        self._pay(self.member, months_ago(1), amount="400")
        self._pay(self.member, months_ago(1, day=20), amount="400")  # 800 total: below the minimum
        self.assertGreaterEqual(activity.missed_contribution_months(self.member), 1)


class MeetingRuleTests(ActivityTestBase):
    def test_consecutive_absences_and_apology_breaks_the_streak(self):
        oldest, middle, newest = self._held_meeting(60), self._held_meeting(30), self._held_meeting(2)
        MeetingAttendance.objects.create(meeting=oldest, member=self.member, status=AttendanceStatus.APOLOGY)
        MeetingAttendance.objects.create(meeting=middle, member=self.member, status=AttendanceStatus.ABSENT)
        MeetingAttendance.objects.create(meeting=newest, member=self.member, status=AttendanceStatus.ABSENT)
        self.assertEqual(activity.missed_meetings(self.member), 2)

    def test_closing_the_register_marks_everyone_unmarked_absent(self):
        meeting = meetings.schedule_meeting(
            meeting_type="MONTHLY", title="September", scheduled_at=timezone.now() + timedelta(days=3), send_notice=False
        )
        other = self._member("M-00003", joined=months_ago(2))
        meetings.send_apology(meeting=meeting, member=other, reason="Travelling")
        self.assertEqual(meetings.close_register(meeting=meeting), 1)  # self.member marked absent
        self.assertEqual(MeetingAttendance.objects.get(meeting=meeting, member=self.member).status, AttendanceStatus.ABSENT)
        self.assertEqual(MeetingAttendance.objects.get(meeting=meeting, member=other).status, AttendanceStatus.APOLOGY)


class ArchiveAndReactivateTests(ActivityTestBase):
    def test_check_warns_once_then_flags_and_secretary_confirms(self):
        self._pay(self.member, months_ago(3))  # 2 months missed: warning level
        result = activity.run_activity_check()
        self.assertEqual((result["flagged"], result["warned"]), (0, 1))
        self.assertEqual(activity.run_activity_check()["warned"], 0)  # not repeated

        next_month = (date.today().replace(day=28) + timedelta(days=4)).replace(day=1)
        flagged = activity.run_activity_check(today=next_month)  # a month later: 3 missed
        self.assertEqual(flagged["flagged"], 1)
        flag = InactivityFlag.objects.get(member=self.member, status=InactivityFlag.PENDING)

        activity.confirm_flag(flag, confirmed_by=self.secretary)
        self.member.refresh_from_db()
        self.assertEqual(self.member.status, "DORMANT")
        self.assertEqual(MemberStatusChange.objects.get(member=self.member).to_status, "DORMANT")

    def test_dormant_member_cannot_borrow_and_is_not_covered_by_welfare(self):
        from loans.models import LoanProduct
        from loans.services import apply_for_loan
        from welfare.models import WelfareCaseType
        from welfare.services import create_case

        Member.objects.filter(pk=self.member.pk).update(status="DORMANT")
        self.member.refresh_from_db()
        product = LoanProduct.objects.create(name="Dev", code="dev", interest_method="FLAT", interest_rate=D("0.1"))
        with self.assertRaises(ValueError):
            apply_for_loan(member=self.member, product=product, amount_requested=D("1000"), term_months=3)
        case_type = WelfareCaseType.objects.create(name="Sick", contribution_per_member=D("100"))
        with self.assertRaises(ValueError):
            create_case(case_type=case_type, beneficiary=self.member)

    def test_contributing_again_reactivates_automatically(self):
        Member.objects.filter(pk=self.member.pk).update(status="DORMANT")
        self._pay(self.member, date.today())
        self.member.refresh_from_db()
        self.assertEqual(self.member.status, "ACTIVE")
        self.assertIn("automatically", MemberStatusChange.objects.get(member=self.member).reason)

    def test_attending_a_meeting_reactivates_automatically(self):
        Member.objects.filter(pk=self.member.pk).update(status="DORMANT")
        meeting = self._held_meeting(0)
        meetings.record_attendance(meeting=meeting, entries=[{"member": self.member, "status": AttendanceStatus.PRESENT}])
        self.member.refresh_from_db()
        self.assertEqual(self.member.status, "ACTIVE")

    def test_nobody_archives_themself(self):
        flag = InactivityFlag.objects.create(member=self.member, reason=InactivityFlag.CONTRIBUTIONS, detail="x")
        with self.assertRaises(ValueError):
            activity.confirm_flag(flag, confirmed_by=self.user)


class ApiTests(ActivityTestBase):
    def setUp(self):
        super().setUp()
        self.client = TenantClient(self.tenant)

    def test_member_sends_apology_and_secretary_takes_register(self):
        meeting = meetings.schedule_meeting(
            meeting_type="MONTHLY", title="October", scheduled_at=timezone.now() + timedelta(days=5), send_notice=False
        )
        self.client.force_login(self.user)
        response = self.client.post(f"/api/governance/meetings/{meeting.id}/apology/", {"reason": "Sick child"},
                                    content_type="application/json")
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()["my_attendance"]["status"], "APOLOGY")
        self.assertEqual(self.client.get(f"/api/governance/meetings/{meeting.id}/register/").status_code, 403)

        self.client.force_login(self.secretary)
        register = self.client.get(f"/api/governance/meetings/{meeting.id}/register/").json()
        self.assertEqual(register["rows"][0]["status"], "APOLOGY")
        self.assertEqual(self.client.post(f"/api/governance/meetings/{meeting.id}/close/").status_code, 200)

    def test_secretary_runs_check_and_member_sees_their_standing(self):
        self.client.force_login(self.secretary)
        self.assertEqual(self.client.post("/api/members/activity/run/").status_code, 200)
        self.assertEqual(self.client.get("/api/members/activity/flags/").json()["results"][0]["member_number"], "M-00001")
        self.client.force_login(self.user)
        standing = self.client.get("/api/members/me/activity/").json()
        self.assertEqual(standing["status"], "ACTIVE")
        self.assertGreaterEqual(standing["missed_months"], 3)
