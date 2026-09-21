from datetime import timedelta

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.utils import timezone
from django_tenants.test.cases import TenantTestCase
from django_tenants.test.client import TenantClient

from accesscontrol.models import Membership, Role
from identity.models import TenantAccess, User
from members.models import Member

from . import papers
from .models import Meeting, MeetingStatus, MinutesStatus

PDF = b"%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF"


@override_settings(STORAGES={
    "default": {"BACKEND": "django.core.files.storage.InMemoryStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
})
class MeetingPapersTests(TenantTestCase):
    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        self.client = TenantClient(self.tenant)
        self.secretary = self._user("+254711555001", "Secretary")
        self.chair = self._user("+254711555002", "Chairperson")
        self.member_user = self._user("+254711555003", "Member")
        Member.objects.create(member_number="IW-26-00001", user=self.member_user, first_name="Mary", last_name="W",
                              id_type="NATIONAL_ID", id_number="1", phone_number="+254711555003")
        self.meeting = Meeting.objects.create(
            meeting_type="MONTHLY", title="October monthly meeting", agenda="1. Welfare report\n2. Loans",
            scheduled_at=timezone.now() - timedelta(days=1),
        )

    def _user(self, phone, role):
        user = User.objects.create_user(phone_number=phone, password="pass12345", first_name=role)
        TenantAccess.objects.create(user=user, tenant=self.tenant)
        Membership.objects.create(user=user, role=Role.objects.get(name=role))
        return user

    def _held(self, meeting=None):
        meeting = meeting or self.meeting
        meeting.status = MeetingStatus.HELD
        meeting.save(update_fields=["status"])

    def test_template_numbers_minutes_from_the_agenda(self):
        body = papers.draft_template(self.meeting)
        month = self.meeting.scheduled_at.strftime("%m/%Y")
        self.assertIn(f"MIN 01/{month}: WELFARE REPORT", body)
        self.assertIn(f"MIN 02/{month}: LOANS", body)

    def test_secretary_drafts_chair_approves_then_locked(self):
        papers.save_draft(meeting=self.meeting, body="MIN 01: Opened", by=self.secretary)
        with self.assertRaisesMessage(ValueError, "register"):
            papers.submit(meeting=self.meeting, by=self.secretary)  # not held yet
        self._held()
        papers.submit(meeting=self.meeting, by=self.secretary)
        with self.assertRaises(ValueError):
            papers.approve(meeting=self.meeting, by=self.secretary)  # never your own
        minutes = papers.approve(meeting=self.meeting, by=self.chair)
        self.assertEqual(minutes.status, MinutesStatus.APPROVED)
        with self.assertRaisesMessage(ValueError, "locked"):
            papers.save_draft(meeting=self.meeting, body="changed", by=self.secretary)
        papers.add_addendum(meeting=self.meeting, text="Correction: meeting ended 4pm", by=self.secretary)
        self.assertEqual(minutes.addenda.count(), 1)

    def test_chair_can_send_minutes_back(self):
        self._held()
        papers.save_draft(meeting=self.meeting, body="draft", by=self.secretary)
        papers.submit(meeting=self.meeting, by=self.secretary)
        minutes = papers.send_back(meeting=self.meeting, by=self.chair, comment="Add the loans resolution")
        self.assertEqual(minutes.status, MinutesStatus.DRAFT)
        papers.save_draft(meeting=self.meeting, body="draft + loans", by=self.secretary)

    def test_members_see_minutes_only_once_approved(self):
        self._held()
        papers.save_draft(meeting=self.meeting, body="secret draft", by=self.secretary)
        self.client.force_login(self.member_user)
        r = self.client.get(f"/api/governance/meetings/{self.meeting.pk}/minutes/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["body"], "")
        papers.submit(meeting=self.meeting, by=self.secretary)
        papers.approve(meeting=self.meeting, by=self.chair)
        r = self.client.get(f"/api/governance/meetings/{self.meeting.pk}/minutes/")
        self.assertEqual(r.json()["body"], "secret draft")
        pdf = self.client.get(f"/api/governance/meetings/{self.meeting.pk}/minutes/pdf/")
        self.assertEqual(pdf.status_code, 200)
        self.assertTrue(pdf.content.startswith(b"%PDF"))

    def test_documents_upload_download_and_withdraw(self):
        self.client.force_login(self.secretary)
        r = self.client.post(
            f"/api/governance/meetings/{self.meeting.pk}/documents/",
            {"file": SimpleUploadedFile("Treasurer report.pdf", PDF, content_type="application/pdf"),
             "title": "Treasurer's report", "kind": "REPORT"},
        )
        self.assertEqual(r.status_code, 201, r.content)
        doc = r.json()
        self.client.force_login(self.member_user)
        download = self.client.get(doc["download_path"])
        self.assertEqual(download.status_code, 200)
        self.assertEqual(b"".join(download.streaming_content), PDF)
        self.assertEqual(self.client.post(f"/api/governance/meetings/{self.meeting.pk}/documents/",
                                          {"file": SimpleUploadedFile("x.pdf", PDF)}).status_code, 403)
        self.client.force_login(self.secretary)
        self.client.post(f"/api/governance/documents/{doc['id']}/withdraw/", {"reason": "Wrong file"},
                         content_type="application/json")
        self.client.force_login(self.member_user)
        self.assertEqual(self.client.get(f"/api/governance/meetings/{self.meeting.pk}/documents/").json(), [])

    def test_board_papers_are_confidential(self):
        board = Meeting.objects.create(meeting_type="BOARD", title="Board", scheduled_at=timezone.now())
        self.client.force_login(self.member_user)
        self.assertEqual(self.client.get(f"/api/governance/meetings/{board.pk}/documents/").status_code, 403)
        self.client.force_login(self.chair)
        self.assertEqual(self.client.get(f"/api/governance/meetings/{board.pk}/documents/").status_code, 200)

    def test_rejects_unknown_file_types(self):
        with self.assertRaises(ValueError):
            papers.upload_document(meeting=self.meeting, uploaded=SimpleUploadedFile("run.exe", b"MZ\x90\x00junk"),
                                   title="x", kind="ATTACHMENT", by=self.secretary)
