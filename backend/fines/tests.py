from datetime import date, timedelta
from decimal import Decimal as D

from django.utils import timezone
from django_tenants.test.cases import TenantTestCase

from accesscontrol.models import Membership, Role
from accounting.models import Account, JournalLine
from governance.models import AttendanceStatus, Meeting, MeetingAttendance
from identity.models import TenantAccess, User
from members.models import Member

from . import services
from .models import Fine, FineStatus, OffenceType


class FinesTests(TenantTestCase):
    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        self.absence = OffenceType.objects.create(name="Absent without apology", amount=D("200"),
                                                  from_attendance="ABSENT")
        self.late = OffenceType.objects.create(name="Late to meeting", amount=D("100"), from_attendance="LATE")
        self.member = self._member("IW-26-00001", "Mary")
        self.other = self._member("IW-26-00002", "John")
        self.clerk = self._user("+254711444001", "Secretary")
        self.chair = self._user("+254711444002", "Chairperson")

    def _member(self, number, name):
        return Member.objects.create(member_number=number, first_name=name, last_name="Test",
                                     id_type="NATIONAL_ID", id_number=number, phone_number="")

    def _user(self, phone, role):
        user = User.objects.create_user(phone_number=phone, password="pass12345", first_name=role)
        TenantAccess.objects.create(user=user, tenant=self.tenant)
        Membership.objects.create(user=user, role=Role.objects.get(name=role))
        return user

    def _entry_balances(self, entry):
        debits = sum(line.debit for line in entry.lines.all())
        credits = sum(line.credit for line in entry.lines.all())
        self.assertEqual(debits, credits)
        return debits

    def test_charging_a_fine_posts_a_balanced_entry_the_member_owes(self):
        fine = services.charge_fine(member=self.member, offence_type=self.absence, incurred_on=date.today(),
                                    charged_by=self.clerk)
        self.assertEqual(self._entry_balances(fine.journal_entry), D("200"))
        self.assertEqual(Account.objects.get(code="1400").balance(member=self.member), D("200"))
        self.assertEqual(Account.objects.get(code="5200").balance(), D("200"))
        self.assertEqual(services.outstanding_total(self.member), D("200"))

    def test_payment_clears_oldest_fines_first_and_cannot_overpay(self):
        old = services.charge_fine(member=self.member, offence_type=self.absence,
                                   incurred_on=date.today() - timedelta(days=30), charged_by=self.clerk)
        recent = services.charge_fine(member=self.member, offence_type=self.late, incurred_on=date.today(),
                                      charged_by=self.clerk)
        services.record_payment(member=self.member, amount=D("250"), method="CASH", paid_on=date.today(),
                                idempotency_key="p1")
        old.refresh_from_db()
        recent.refresh_from_db()
        self.assertEqual(old.status, FineStatus.PAID)
        self.assertEqual(recent.paid, D("50"))
        self.assertEqual(services.outstanding_total(self.member), D("50"))
        with self.assertRaisesMessage(ValueError, "only owes"):
            services.record_payment(member=self.member, amount=D("100"), method="CASH", paid_on=date.today(),
                                    idempotency_key="p2")

    def test_a_retried_payment_is_not_posted_twice(self):
        services.charge_fine(member=self.member, offence_type=self.absence, incurred_on=date.today())
        for _ in range(2):
            services.record_payment(member=self.member, amount=D("200"), method="MOBILE_MONEY",
                                    paid_on=date.today(), idempotency_key="same-key")
        self.assertEqual(services.outstanding_total(self.member), D("0"))
        self.assertEqual(JournalLine.objects.filter(account__code="1400", credit=D("200")).count(), 1)

    def test_waiver_reverses_what_is_owed_and_needs_a_second_person(self):
        fine = services.charge_fine(member=self.member, offence_type=self.absence, incurred_on=date.today(),
                                    charged_by=self.clerk)
        with self.assertRaisesMessage(ValueError, "someone else"):
            services.waive_fine(fine=fine, by=self.clerk, reason="Was sick")
        services.waive_fine(fine=fine, by=self.chair, reason="Was sick")
        fine.refresh_from_db()
        self.assertEqual(fine.status, FineStatus.WAIVED)
        self.assertEqual(services.outstanding_total(self.member), D("0"))
        self.assertEqual(Account.objects.get(code="5200").balance(), D("0"))  # income reversed too

    def test_register_proposes_fines_and_charges_only_confirmed_members(self):
        meeting = Meeting.objects.create(meeting_type="MONTHLY", title="September meeting",
                                         scheduled_at=timezone.now() - timedelta(days=2), status="HELD")
        MeetingAttendance.objects.create(meeting=meeting, member=self.member, status=AttendanceStatus.ABSENT)
        MeetingAttendance.objects.create(meeting=meeting, member=self.other, status=AttendanceStatus.LATE)
        proposals = services.proposals_from_meeting(meeting)
        self.assertEqual({p["member"].member_number: p["amount"] for p in proposals},
                         {"IW-26-00001": D("200"), "IW-26-00002": D("100")})
        charged = services.charge_from_meeting(meeting=meeting, member_ids=[str(self.member.pk)],
                                               charged_by=self.clerk)
        self.assertEqual(charged, 1)
        self.assertEqual(Fine.objects.count(), 1)
        # Running it again doesn't charge the same person twice.
        self.assertEqual(services.charge_from_meeting(meeting=meeting, member_ids=[str(self.member.pk)]), 0)

    def test_charging_many_members_is_all_or_nothing(self):
        entries = [{"member": self.member, "amount": D("600")}, {"member": self.other, "amount": D("0")}]
        with self.assertRaises(ValueError):
            services.charge_many(offence_type=self.absence, entries=entries, incurred_on=date.today())
        self.assertEqual(Fine.objects.count(), 0)  # the good line was rolled back too
        entries[1]["amount"] = D("200")
        fines = services.charge_many(offence_type=self.absence, entries=entries, incurred_on=date.today(),
                                     charged_by=self.clerk, notes="12 Jul - 13 Sep")
        self.assertEqual([f.amount for f in fines], [D("600"), D("200")])
        self.assertEqual(services.outstanding_total(self.member), D("600"))

    def test_summary_totals_ignore_waived_fines(self):
        services.charge_fine(member=self.member, offence_type=self.absence, incurred_on=date.today())
        waived = services.charge_fine(member=self.other, offence_type=self.late, incurred_on=date.today())
        services.waive_fine(fine=waived, by=self.chair, reason="Bereaved")
        self.assertEqual(services.member_summary(self.member)["outstanding"], D("200"))
        self.assertEqual(services.member_summary(self.other)["outstanding"], D("0"))
