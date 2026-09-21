import time

from django.db import connection
from django_tenants.utils import get_public_schema_name

from . import services

# Sign-ins are recorded by the login view itself (it knows who tried and
# whether it worked); token refreshes are background noise.
SKIP_PREFIXES = ("/api/auth/token/", "/api/public/", "/api/payments/callbacks/")


class AuditMiddleware:
    """Records every signed-in API request in this SACCO's audit log: who,
    what (in plain words), when, from where and on which device."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        started = time.monotonic()
        response = self.get_response(request)
        path = request.path
        if (
            path.startswith("/api/")
            and not path.startswith(SKIP_PREFIXES)
            and request.method not in ("OPTIONS", "HEAD")
            and connection.schema_name != get_public_schema_name()
        ):
            # DRF sets request.user on the underlying request once the JWT
            # has been checked, so it is the real person here.
            user = getattr(request, "user", None)
            if getattr(user, "is_authenticated", False):
                action, area, summary, target_id = services.describe(request.method, path)
                services.record(
                    request=request, user=user, action=action, area=area, summary=summary,
                    method=request.method, path=path, status_code=response.status_code,
                    duration_ms=int((time.monotonic() - started) * 1000), target_id=target_id,
                )
        return response
