from django.db import connection
from rest_framework.generics import RetrieveUpdateAPIView
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from tenants.models import Tenant

from .permissions import require_permission
from .serializers import MyTenantProfileSerializer, TenantUpdateSerializer


class MyTenantProfileView(APIView):
    """
    This SACCO's profile plus the logged-in user's role(s) in it. Only
    reachable within a tenant's own urlconf (never the public one), so
    connection.schema_name here is always a real SACCO.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(MyTenantProfileSerializer(request).data)


class TenantProfileUpdateView(RetrieveUpdateAPIView):
    """
    Edit this SACCO's own profile (name, contact details, logo) after
    creation. multipart-capable for the logo upload; plain JSON still works
    for text-only updates.
    """

    serializer_class = TenantUpdateSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_object(self):
        return Tenant.objects.get(schema_name=connection.schema_name)

    def get_permissions(self):
        code = "admin.manage_tenant" if self.request.method in ("PUT", "PATCH") else "configuration.view"
        return [IsAuthenticated(), require_permission(code)()]
