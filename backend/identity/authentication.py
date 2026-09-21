from django.db import connection
from django_tenants.utils import get_public_schema_name
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.authentication import JWTAuthentication

from .models import TenantAccess


class TenantJWTAuthentication(JWTAuthentication):
    """JWT, plus: the person's access to *this* SACCO must still be active.
    Disabling someone's login (accesscontrol users/<id>/disable/) takes
    effect on their very next request, not when their token expires."""

    def authenticate(self, request):
        result = super().authenticate(request)
        if result is None or connection.schema_name == get_public_schema_name():
            return result
        user, _token = result
        if not TenantAccess.objects.filter(
            user=user, tenant__schema_name=connection.schema_name, is_active=True
        ).exists():
            raise AuthenticationFailed("Your access to this SACCO has been disabled. Contact the administrator.")
        return result
