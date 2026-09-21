from django.test import override_settings
from django_tenants.test.cases import TenantTestCase
from rest_framework.test import APIRequestFactory

from .models import Domain
from .views import SaccoLookupView


class SaccoLookupTests(TenantTestCase):
    """Public SACCO-code lookup the mobile app uses to find its tenant's host."""

    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "TZ"
        tenant.currency = "TZS"

    @classmethod
    def get_test_tenant_domain(cls):
        return "shirika.localhost"

    def _lookup(self, code):
        request = APIRequestFactory().get(f"/api/public/saccos/{code}/")
        return SaccoLookupView.as_view()(request, code=code)

    def test_resolves_code_to_domain_and_branding(self):
        response = self._lookup("shirika")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["domain"], "shirika.localhost")
        self.assertEqual(response.data["name"], "Test SACCO")
        self.assertEqual(response.data["currency"], "TZS")

    def test_code_is_case_and_hostname_tolerant(self):
        self.assertEqual(self._lookup("SHIRIKA").status_code, 200)
        self.assertEqual(self._lookup("shirika.example.com").data["domain"], "shirika.localhost")

    @override_settings(TENANT_BASE_DOMAIN="10.0.0.5.nip.io")
    def test_prefers_the_phone_reachable_base_domain(self):
        Domain.objects.create(domain="shirika.10.0.0.5.nip.io", tenant=self.tenant, is_primary=False)
        self.assertEqual(self._lookup("shirika").data["domain"], "shirika.10.0.0.5.nip.io")

    def test_unknown_code_is_404(self):
        self.assertEqual(self._lookup("nope").status_code, 404)

    def test_inactive_sacco_is_not_found(self):
        self.tenant.is_active = False
        self.tenant.save(update_fields=["is_active"])
        self.assertEqual(self._lookup("shirika").status_code, 404)
