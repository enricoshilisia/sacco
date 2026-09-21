from decimal import Decimal

from django_tenants.test.cases import TenantTestCase
from django_tenants.test.client import TenantClient

from identity.models import User
from members.models import Member

from .models import CollectionPurpose, CollectionStatus, PaymentCollection


class MyCollectionsTests(TenantTestCase):
    """The self-service collection endpoints (used by the mobile app to
    follow an STK push to completion) must only ever show the caller's
    own collections."""

    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        self.client = TenantClient(self.tenant)
        self.user = User.objects.create_user(phone_number="+254700000101", password="pass12345")
        self.member = self._member("M-00001", user=self.user)
        self.other_member = self._member("M-00002")
        self.mine = self._collection(self.member, "key-mine")
        self.theirs = self._collection(self.other_member, "key-theirs")
        self.client.force_login(self.user)

    def _member(self, number, user=None):
        return Member.objects.create(
            member_number=number, user=user, first_name="A", last_name="B",
            id_type="NATIONAL_ID", id_number=number, phone_number="+254700000999",
        )

    def _collection(self, member, key):
        return PaymentCollection.objects.create(
            idempotency_key=key, member=member, purpose=CollectionPurpose.SHARE_CONTRIBUTION,
            provider="mock", phone_number="+254700000999", amount=Decimal("250.00"),
            status=CollectionStatus.PENDING,
        )

    def test_list_returns_only_my_collections(self):
        response = self.client.get("/api/payments/me/collections/")
        self.assertEqual(response.status_code, 200)
        ids = [row["id"] for row in response.json()["results"]]
        self.assertEqual(ids, [str(self.mine.id)])

    def test_detail_of_my_collection(self):
        response = self.client.get(f"/api/payments/me/collections/{self.mine.id}/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "PENDING")
        # Money stays a string on the wire (CLAUDE.md rule 1).
        self.assertEqual(response.json()["amount"], "250.00")

    def test_detail_of_someone_elses_collection_is_404(self):
        response = self.client.get(f"/api/payments/me/collections/{self.theirs.id}/")
        self.assertEqual(response.status_code, 404)

    def test_requires_authentication(self):
        self.client.logout()
        response = self.client.get("/api/payments/me/collections/")
        self.assertIn(response.status_code, (401, 403))
