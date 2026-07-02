from rest_framework.generics import RetrieveUpdateAPIView
from rest_framework.permissions import IsAuthenticated

from accesscontrol.permissions import require_permission

from .models import TenantConfig
from .serializers import TenantConfigSerializer


class TenantConfigView(RetrieveUpdateAPIView):
    """
    This SACCO's settings - currently language, allowed ID types, and
    member-number style. Only reachable within a tenant's own urlconf, so
    get_solo() always operates on the right schema's singleton row.
    """

    serializer_class = TenantConfigSerializer

    def get_object(self):
        return TenantConfig.get_solo()

    def get_permissions(self):
        code = "configuration.edit" if self.request.method in ("PUT", "PATCH") else "configuration.view"
        return [IsAuthenticated(), require_permission(code)()]
