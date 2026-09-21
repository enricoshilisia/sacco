from django.conf import settings
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Domain


class SaccoLookupView(APIView):
    """
    Public (no auth) - resolve a SACCO's short code (the first label of its
    domain, e.g. "nairobi" for nairobi.<base>) to the host its API lives
    on, plus enough branding for a login screen. The web frontend never
    needs this - the browser's own hostname already picks the tenant (see
    frontend/src/lib/api.ts) - but a native mobile app has no hostname of
    its own, so it asks here once and then talks to that host directly.

    Only reachable via the public-schema urlconf (config/urls_public.py).
    Returns nothing a member of the public couldn't already learn by
    visiting the SACCO's subdomain; never anything about members.
    """

    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request, code):
        label = code.strip().lower().split(".")[0]
        domains = list(
            Domain.objects.select_related("tenant")
            .filter(domain__startswith=f"{label}.", tenant__is_active=True)
        )
        if not domains:
            return Response({"detail": "No SACCO found with that code."}, status=status.HTTP_404_NOT_FOUND)

        # A tenant commonly carries both a .localhost Domain (local dev,
        # unreachable from a phone) and a TENANT_BASE_DOMAIN one (see
        # README: "Accessing this from outside the server") - prefer the
        # latter, then whichever is primary.
        base_domain = getattr(settings, "TENANT_BASE_DOMAIN", "localhost")
        domains.sort(key=lambda d: (not d.domain.endswith(f".{base_domain}"), not d.is_primary))
        domain = domains[0]
        tenant = domain.tenant

        logo_url = None
        if tenant.logo:
            try:
                logo_url = tenant.logo.url
            except Exception:
                logo_url = None

        return Response(
            {
                "code": label,
                "name": tenant.name,
                "country": tenant.country,
                "currency": tenant.currency,
                "default_language": tenant.default_language,
                "logo": logo_url,
                "domain": domain.domain,
            }
        )
