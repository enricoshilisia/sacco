from datetime import date
from decimal import Decimal as D
from unittest import mock

from django_tenants.test.cases import TenantTestCase
from django_tenants.test.client import TenantClient

from accesscontrol import services as access
from accesscontrol.models import Membership, Role
from accounting.models import Account, JournalLine
from audit.models import AuditEvent
from identity.models import TenantAccess, User
from loans.models import LoanProduct
from loans.services import apply_for_loan
from savings.models import SavingsProduct
from savings.services import deposit_savings, get_or_open_savings_account

from . import admission
from .models import Member, MembershipSettings


def months_ago(n, day=15):
    d = date.today().replace(day=1)
    for _ in range(n):
        d = (d.replace(day=1) - __import__("datetime").timedelta(days=1)).replace(day=1)
    return d.replace(day=day)


APPLICANT = {
    "first_name": "Neema", "last_name": "Atieno", "id_type": "NATIONAL_ID", "id_number": "30111222",
    "phone_number": "+254722000555",
}


class AdmissionTests(TenantTestCase):
    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        self.sms = mock.patch("notifications.tasks.send_notification_task.delay").start()
        self.addCleanup(mock.patch.stopall)
        self.secretary = self._user("+254711777001", "Secretary")
        self.chair = self._user("+254711777002", "Chairperson")
        self.monthly = SavingsProduct.objects.create(name="Monthly", code="monthly", product_type="MANDATORY_MONTHLY")
        settings = MembershipSettings.get_solo()
        settings.registration_fee = D("1000")
        settings.save()

    def _user(self, phone, role):
        user = User.objects.create_user(phone_number=phone, password="pass12345", first_name=role)
        TenantAccess.objects.create(user=user, tenant=self.tenant)
        Membership.objects.create(user=user, role=Role.objects.get(name=role))
        return user

    def _submit(self, **extra):
        return admission.submit_application(data={**APPLICANT, **extra}, submitted_by=self.secretary)

    def test_secretary_registers_chair_approves_creates_member_and_login(self):
        application = self._submit()
        application, temporary = admission.approve_application(application, by=self.chair)
        member = application.member
        self.assertTrue(member.member_number)
        self.assertFalse(member.is_verified)
        self.assertEqual(member.profile_status, "APPROVED")
        self.assertTrue(temporary)
        user = member.user
        self.assertTrue(user.check_password(temporary))
        self.assertTrue(user.must_change_password)
        self.assertTrue(TenantAccess.objects.filter(user=user, tenant=self.tenant, is_active=True).exists())
        self.assertTrue(Membership.objects.filter(user=user, role__name="Member").exists())

    def test_year_style_member_numbers_restart_each_year(self):
        from configuration.models import TenantConfig

        from .services import generate_member_number

        config = TenantConfig.objects.first() or TenantConfig.objects.create()
        config.member_number_prefix = "IW-"
        config.member_number_include_year = True
        config.member_number_sequence_year = date.today().year - 1
        config.member_number_next_sequence = 57
        config.save()
        yy = f"{date.today().year % 100:02d}"
        self.assertEqual(generate_member_number(), f"IW-{yy}-00001")
        self.assertEqual(generate_member_number(), f"IW-{yy}-00002")

    def test_nobody_approves_their_own_registration(self):
        application = self._submit()
        Membership.objects.create(user=self.secretary, role=Role.objects.get(name="Chairperson"))
        with self.assertRaises(ValueError):
            admission.approve_application(application, by=self.secretary)

    def test_duplicate_id_is_refused(self):
        self._submit()
        with self.assertRaises(ValueError):
            self._submit(phone_number="+254722000556")

    def test_fee_collected_at_registration_posts_on_approval_and_ledger_balances(self):
        application = self._submit(fee_collected=D("1000"), fee_method="CASH", fee_reference="RCPT-1")
        self.assertEqual(Account.objects.get(code="5100").balance(), D("0"))  # not before approval
        application, _ = admission.approve_application(application, by=self.chair)
        income = JournalLine.objects.filter(account__code="5100").first()
        entry = income.journal_entry
        debits = sum(l.debit for l in entry.lines.all())
        credits = sum(l.credit for l in entry.lines.all())
        self.assertEqual(debits, credits)
        self.assertEqual(income.credit, D("1000"))
        self.assertEqual(admission.fee_paid(application.member), D("1000"))

    def test_fee_is_idempotent_and_cannot_exceed_the_fee(self):
        member = admission.approve_application(self._submit(), by=self.chair)[0].member
        admission.record_registration_fee(member=member, amount=D("600"), method="CASH", paid_on=date.today(),
                                          idempotency_key="k1")
        admission.record_registration_fee(member=member, amount=D("600"), method="CASH", paid_on=date.today(),
                                          idempotency_key="k1")  # retry
        self.assertEqual(admission.fee_paid(member), D("600"))
        with self.assertRaises(ValueError):
            admission.record_registration_fee(member=member, amount=D("500"), method="CASH",
                                              paid_on=date.today(), idempotency_key="k2")

    def _pay_month(self, member, on):
        deposit_savings(savings_account=get_or_open_savings_account(member, self.monthly), amount=D("500"),
                        transaction_date=on)

    def test_verified_after_fee_and_three_consecutive_months(self):
        member = admission.approve_application(self._submit(), by=self.chair)[0].member
        self._pay_month(member, months_ago(3))
        self._pay_month(member, months_ago(1))  # gap: not consecutive
        self._pay_month(member, date.today())
        member.refresh_from_db()
        self.assertFalse(member.is_verified)
        self._pay_month(member, months_ago(2))  # now 3,2,1,0 consecutive
        member.refresh_from_db()
        self.assertFalse(member.is_verified)  # fee still outstanding
        admission.record_registration_fee(member=member, amount=D("1000"), method="CASH", paid_on=date.today(),
                                          idempotency_key="fee")
        member.refresh_from_db()
        self.assertTrue(member.is_verified)

    def test_probation_blocks_borrowing_and_holding_office(self):
        member = admission.approve_application(self._submit(), by=self.chair)[0].member
        product = LoanProduct.objects.create(
            name="Normal", code="normal", interest_rate=D("0.12"), interest_method="REDUCING_BALANCE",
            min_term_months=1, max_term_months=12,
        )
        with self.assertRaisesMessage(ValueError, "probation"):
            apply_for_loan(member=member, product=product, amount_requested=D("100"), term_months=6)
        with self.assertRaisesMessage(ValueError, "probation"):
            access.assign_role(role=Role.objects.get(name="Treasurer"), user=member.user, by=self.chair)


class SupportTests(TenantTestCase):
    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        self.client = TenantClient(self.tenant)
        self.admin = self._user("+254711666001", "SuperAdmin")
        self.it = self._user("+254711666002", "IT Administrator")
        self.member_user = self._user("+254711666003", "Member")

    def _user(self, phone, role):
        user = User.objects.create_user(phone_number=phone, password="pass12345", first_name=role.split()[0])
        TenantAccess.objects.create(user=user, tenant=self.tenant)
        Membership.objects.create(user=user, role=Role.objects.get(name=role))
        return user

    def _token(self, phone, password="pass12345"):
        r = self.client.post("/api/auth/token/", {"phone_number": phone, "password": password},
                             content_type="application/json")
        return r

    def test_reset_password_issues_temporary_and_signs_out_old_sessions(self):
        old = self._token("+254711666003").json()["access"]
        temporary = access.reset_password(user=self.member_user, by=self.it)
        r = self.client.get("/api/tenant/me/", HTTP_AUTHORIZATION=f"Bearer {old}")
        self.assertEqual(r.status_code, 401)  # old token revoked
        login = self._token("+254711666003", temporary)
        self.assertEqual(login.status_code, 200)
        self.assertTrue(login.json()["must_change_password"])
        self.assertTrue(AuditEvent.objects.filter(event="security.password_reset").exists())

    def test_it_admin_cannot_reset_an_administrators_password(self):
        with self.assertRaises(PermissionError):
            access.reset_password(user=self.admin, by=self.it)
        access.reset_password(user=self.it, by=self.admin)  # SuperAdmin can

    def test_disabled_login_is_refused_immediately(self):
        token = self._token("+254711666003").json()["access"]
        access.set_login_enabled(user=self.member_user, enabled=False, by=self.admin)
        r = self.client.get("/api/tenant/me/", HTTP_AUTHORIZATION=f"Bearer {token}")
        self.assertEqual(r.status_code, 401)
        self.assertEqual(self._token("+254711666003").status_code, 400)

    def test_positions_respect_max_holders_and_assignment_is_audited(self):
        chair = Role.objects.get(name="Chairperson")
        self.assertEqual(chair.max_holders, 1)
        access.assign_role(role=chair, user=self.member_user, by=self.admin)
        with self.assertRaisesMessage(ValueError, "full"):
            access.assign_role(role=chair, user=self.it, by=self.admin)
        membership = Membership.objects.get(user=self.member_user, role=chair)
        access.remove_role(membership=membership, by=self.admin)
        access.assign_role(role=chair, user=self.it, by=self.admin)
        self.assertEqual(AuditEvent.objects.filter(area="access").count(), 3)

    def test_assistant_positions_copy_the_principal_permissions(self):
        treasurer = set(Role.objects.get(name="Treasurer").permissions.values_list("code", flat=True))
        assistant = Role.objects.get(name="Assistant Treasurer")
        self.assertEqual(assistant.assistant_of.name, "Treasurer")
        self.assertTrue(treasurer <= set(assistant.permissions.values_list("code", flat=True)))

    def test_requests_and_failed_sign_ins_are_audited_with_device_and_location(self):
        self._token("+254711666003", "wrong-password")
        failed = AuditEvent.objects.get(action="LOGIN_FAILED")
        self.assertIn("+254711666003", failed.summary)

        token = self._token("+254711666002").json()["access"]
        self.client.get(
            "/api/audit/events/", HTTP_AUTHORIZATION=f"Bearer {token}",
            HTTP_X_CLIENT_DEVICE="Tecno KG5 · Android 12 · Inuka West 1.0",
            HTTP_X_CLIENT_LOCATION="-1.283300,36.816700;Nairobi%2C%20Kenya",
        )
        viewed = AuditEvent.objects.filter(action="VIEW", user=self.it).first()
        self.assertEqual(viewed.device, "Tecno KG5 · Android 12 · Inuka West 1.0")
        self.assertEqual(viewed.location, "Nairobi, Kenya")
        self.assertEqual(str(viewed.latitude), "-1.283300")
        self.assertEqual(viewed.summary, "Viewed audit › events")

    def test_sign_in_with_member_number_or_local_phone_format(self):
        Member.objects.create(member_number="IW-00042", user=self.member_user, first_name="Mary", last_name="W",
                              id_type="NATIONAL_ID", id_number="1", phone_number="+254711666003")
        self.assertEqual(self._token("iw-00042").status_code, 200)
        self.assertEqual(self._token("0711666003").status_code, 200)
        self.assertEqual(self._token("254711666003").status_code, 200)
        self.assertEqual(self._token("IW-99999").status_code, 401)

    def test_members_cannot_read_the_audit_log(self):
        token = self._token("+254711666003").json()["access"]
        r = self.client.get("/api/audit/events/", HTTP_AUTHORIZATION=f"Bearer {token}")
        self.assertEqual(r.status_code, 403)

    def test_audit_events_are_append_only(self):
        event = AuditEvent.objects.create(action="EVENT", summary="x")
        event.summary = "changed"
        with self.assertRaises(ValueError):
            event.save()
        with self.assertRaises(ValueError):
            event.delete()
