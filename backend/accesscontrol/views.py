from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .serializers import MyTenantProfileSerializer


class MyTenantProfileView(APIView):
    """
    This SACCO's profile plus the logged-in user's role(s) in it. Only
    reachable within a tenant's own urlconf (never the public one), so
    connection.schema_name here is always a real SACCO.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(MyTenantProfileSerializer(request).data)
