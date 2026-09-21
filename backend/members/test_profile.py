from datetime import date
from decimal import Decimal
from io import BytesIO

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django_tenants.test.cases import TenantTestCase
from django_tenants.test.client import TenantClient
from PIL import Image

from accesscontrol.models import Membership, Role
from identity.models import User

from . import profile_services as s
from .models import Member


def _jpeg(size=(3000, 2000)):
    out = BytesIO()
    Image.new("RGB", size, (20, 90, 160)).save(out, format="JPEG")
    return out.getvalue()


def _years_ago(years):
    today = date.today()
    return today.replace(year=today.year - years)


@override_settings(STORAGES={
    "default": {"BACKEND": "django.core.files.storage.InMemoryStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
})
class ProfileWorkflowTests(TenantTestCase):
    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        self.client = TenantClient(self.tenant)
        self.member_user = User.objects.create_user(phone_number="+254711999101", password="pass12345")
        Membership.objects.create(user=self.member_user, role=Role.objects.get(name="Member"))
        self.member = Member.objects.create(
            member_number="M-00010", user=self.member_user, first_name="Mary", last_name="Wanjiru",
            id_type="NATIONAL_ID", id_number="12345678", phone_number="+254711999101",
        )
        self.secretary = User.objects.create_user(phone_number="+254711999102", password="pass12345")
        Membership.objects.create(user=self.secretary, role=Role.objects.get(name="Secretary"))

    def _approved_family(self, **data):
        request = s.submit_family_add(member=self.member, data=data)
        s.approve_request(request, approved_by=self.secretary)
        request.family_member.refresh_from_db()
        return request.family_member

    def test_protected_change_waits_for_approval_then_applies(self):
        request = s.submit_profile_changes(member=self.member, changes={"last_name": "Kamau"}, note="Married")
        self.member.refresh_from_db()
        self.assertEqual(self.member.last_name, "Wanjiru")  # not applied yet
        self.assertEqual(self.member.profile_status, "PENDING")
        self.assertEqual(request.before, {"last_name": "Wanjiru"})

        s.approve_request(request, approved_by=self.secretary)
        self.member.refresh_from_db()
        self.assertEqual(self.member.last_name, "Kamau")
        self.assertEqual(self.member.profile_status, "APPROVED")
        self.assertTrue(self.member.is_kyc_verified)

    def test_first_submission_with_no_changes_sends_profile_for_approval(self):
        request = s.submit_profile_changes(member=self.member, changes={})
        s.approve_request(request, approved_by=self.secretary)
        self.member.refresh_from_db()
        self.assertEqual(self.member.profile_status, "APPROVED")

    def test_nobody_approves_their_own_profile(self):
        Membership.objects.create(user=self.member_user, role=Role.objects.get(name="Secretary"))
        request = s.submit_profile_changes(member=self.member, changes={"other_names": "Njeri"})
        with self.assertRaises(ValueError):
            s.approve_request(request, approved_by=self.member_user)

    def test_member_cannot_edit_locked_fields_directly_but_can_edit_basic_ones(self):
        self.client.force_login(self.member_user)
        self.client.patch(
            "/api/members/me/",
            {"phone_number": "+254799000000", "first_name": "X", "email": "mary@example.com", "occupation": "Teacher"},
            content_type="application/json",
        )
        self.member.refresh_from_db()
        self.assertEqual(self.member.phone_number, "+254711999101")
        self.assertEqual(self.member.first_name, "Mary")
        self.assertEqual((self.member.email, self.member.occupation), ("mary@example.com", "Teacher"))

    def test_duplicate_id_number_is_caught_on_approval(self):
        Member.objects.create(member_number="M-00011", first_name="Other", last_name="P", id_type="NATIONAL_ID",
                              id_number="99999999", phone_number="+254700000000")
        request = s.submit_profile_changes(member=self.member, changes={"id_number": "99999999"})
        with self.assertRaises(ValueError):
            s.approve_request(request, approved_by=self.secretary)

    def test_family_add_remove_and_reject(self):
        child = self._approved_family(relationship="CHILD", full_name="Baby W", date_of_birth=_years_ago(3))
        self.assertEqual(child.status, "APPROVED")

        s.approve_request(s.submit_family_remove(person=child, note="Entered twice"), approved_by=self.secretary)
        child.refresh_from_db()
        self.assertEqual(child.status, "REMOVED")

        bad = s.submit_family_add(member=self.member, data={"relationship": "SIBLING", "full_name": "Not Real"})
        s.reject_request(bad, rejected_by=self.secretary, notes="No proof")
        bad.family_member.refresh_from_db()
        self.assertEqual(bad.family_member.status, "REJECTED")

    def test_welfare_cover_follows_the_approved_register_and_rules(self):
        from welfare.models import WelfareCaseType
        from welfare.services import create_case

        sick_child = WelfareCaseType.objects.create(
            name="Sick child", contribution_per_member=Decimal("100"), covers=["CHILD"], child_max_age=18
        )
        pending = s.submit_family_add(member=self.member, data={
            "relationship": "CHILD", "full_name": "Kid W", "date_of_birth": _years_ago(5)}).family_member
        with self.assertRaises(ValueError):  # not approved on the register yet
            create_case(case_type=sick_child, beneficiary=self.member, affected_family_member=pending)

        kid = self._approved_family(relationship="CHILD", full_name="Kid Two", date_of_birth=_years_ago(7))
        case = create_case(case_type=sick_child, beneficiary=self.member, affected_family_member=kid)
        self.assertEqual(case.affected_person, "Kid Two (child)")

        with self.assertRaises(ValueError):  # this case type is for a child, not the member
            create_case(case_type=sick_child, beneficiary=self.member)

        adult = self._approved_family(relationship="CHILD", full_name="Adult W", date_of_birth=_years_ago(25))
        with self.assertRaises(ValueError):  # over the child age limit
            create_case(case_type=sick_child, beneficiary=self.member, affected_family_member=adult)

        mother = self._approved_family(relationship="PARENT", full_name="Mama W")
        with self.assertRaises(ValueError):  # relationship not covered by this case type
            create_case(case_type=sick_child, beneficiary=self.member, affected_family_member=mother)

    def test_id_scan_match_and_pdf_documents(self):
        doc = s.upload_document(member=self.member, document_type="ID_FRONT",
                                uploaded=SimpleUploadedFile("id.jpg", _jpeg()), ocr_id_number="12 345 678")
        self.assertTrue(doc.id_number_match)
        doc = s.upload_document(member=self.member, document_type="ID_FRONT",
                                uploaded=SimpleUploadedFile("id.jpg", _jpeg()), ocr_id_number="87654321")
        self.assertFalse(doc.id_number_match)
        pdf = s.upload_document(member=self.member, document_type="BIRTH_CERT",
                                uploaded=SimpleUploadedFile("cert.pdf", b"%PDF-1.4\n%fake\n"))
        self.assertTrue(pdf.file.name.endswith(".pdf"))

    def test_secretary_queue_and_access(self):
        s.submit_profile_changes(member=self.member, changes={"other_names": "Njeri"})
        self.client.force_login(self.secretary)
        response = self.client.get("/api/members/change-requests/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["results"][0]["changes"], {"other_names": "Njeri"})
        self.client.force_login(self.member_user)
        self.assertEqual(self.client.get("/api/members/change-requests/").status_code, 403)
