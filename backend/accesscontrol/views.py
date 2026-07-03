from django.db import connection
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.generics import RetrieveUpdateAPIView
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from identity.models import TenantAccess, User
from identity.serializers import UserSerializer
from tenants.models import Tenant

from .models import Membership, Role, StaffInvite
from .permissions import require_permission
from .serializers import (
    MyTenantProfileSerializer,
    RoleSerializer,
    StaffInviteSerializer,
    StaffMembershipSerializer,
    TenantUpdateSerializer,
)


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


# Roles a SACCO admin can hand to staff via an invite. "Member" and
# "Guarantor" are granted automatically elsewhere (self-registration, loan
# guarantor pledges) - they're not something an admin hands out here.
STAFF_ASSIGNABLE_ROLE_EXCLUSIONS = ["Member", "Guarantor"]


class RoleListView(generics.ListAPIView):
    serializer_class = RoleSerializer
    permission_classes = [IsAuthenticated, require_permission("accesscontrol.assign_roles")]
    queryset = Role.objects.exclude(name__in=STAFF_ASSIGNABLE_ROLE_EXCLUSIONS)


class StaffListView(generics.ListAPIView):
    """The staff/governance roster: one row per active Membership."""

    serializer_class = StaffMembershipSerializer
    permission_classes = [IsAuthenticated, require_permission("accesscontrol.assign_roles")]
    queryset = Membership.objects.select_related("role").order_by("-assigned_at")


def _is_last_active_super_admin(membership: Membership) -> bool:
    if membership.role.name != "SuperAdmin" or not membership.is_active:
        return False
    return not Membership.objects.filter(
        role__name="SuperAdmin", is_active=True
    ).exclude(pk=membership.pk).exists()


class StaffMembershipUpdateView(generics.UpdateAPIView):
    """Change a staff member's role/job title, or deactivate/reactivate them."""

    serializer_class = StaffMembershipSerializer
    permission_classes = [IsAuthenticated, require_permission("accesscontrol.assign_roles")]
    queryset = Membership.objects.select_related("role")
    http_method_names = ["patch"]

    def patch(self, request, *args, **kwargs):
        membership = self.get_object()
        demoting_or_deactivating = (
            "is_active" in request.data and not request.data["is_active"]
        ) or ("role" in request.data and str(request.data["role"]) != str(membership.role_id))
        if demoting_or_deactivating and _is_last_active_super_admin(membership):
            return Response(
                {"detail": "This SACCO must always have at least one active SuperAdmin."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return self.partial_update(request, *args, **kwargs)


class StaffInviteListCreateView(generics.ListCreateAPIView):
    serializer_class = StaffInviteSerializer
    permission_classes = [IsAuthenticated, require_permission("accesscontrol.assign_roles")]
    queryset = StaffInvite.objects.select_related("role")

    def perform_create(self, serializer):
        serializer.save(invited_by=self.request.user)


class StaffInviteRevokeView(APIView):
    permission_classes = [IsAuthenticated, require_permission("accesscontrol.assign_roles")]

    def post(self, request, pk):
        invite = get_object_or_404(StaffInvite, pk=pk)
        if invite.status != "pending":
            return Response(
                {"detail": f"This invite is already {invite.status}."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        invite.revoked_at = timezone.now()
        invite.save(update_fields=["revoked_at"])
        return Response(StaffInviteSerializer(invite).data)


class StaffInviteAcceptView(APIView):
    """
    Public (no auth) - the destination of the setup link an admin shares
    out of band. GET prefills the accept-invite page; POST creates (or
    reuses) the account and grants the invited role. Only reachable within
    a tenant's own urlconf, same as /api/auth/register.
    """

    permission_classes = [AllowAny]

    def get(self, request, token):
        invite = get_object_or_404(StaffInvite, token=token)
        if invite.status != "pending":
            return Response({"detail": f"This invite is {invite.status}."}, status=status.HTTP_400_BAD_REQUEST)
        tenant = Tenant.objects.get(schema_name=connection.schema_name)
        existing_account = User.objects.filter(phone_number=invite.phone_number).exists()
        return Response(
            {
                "first_name": invite.first_name,
                "last_name": invite.last_name,
                "role_name": invite.role.name,
                "job_title": invite.job_title,
                "sacco_name": tenant.name,
                "existing_account": existing_account,
            }
        )

    def post(self, request, token):
        invite = get_object_or_404(StaffInvite, token=token)
        if invite.status != "pending":
            return Response({"detail": f"This invite is {invite.status}."}, status=status.HTTP_400_BAD_REQUEST)

        password = request.data.get("password", "")
        existing_user = User.objects.filter(phone_number=invite.phone_number).first()

        if existing_user:
            if not existing_user.check_password(password):
                return Response(
                    {"detail": "Incorrect password for this existing account."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user = existing_user
        else:
            if len(password) < 8:
                return Response(
                    {"detail": "Password must be at least 8 characters."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user = User.objects.create_user(
                phone_number=invite.phone_number,
                email=invite.email,
                first_name=invite.first_name,
                last_name=invite.last_name,
                password=password,
            )

        tenant = Tenant.objects.get(schema_name=connection.schema_name)
        TenantAccess.objects.get_or_create(user=user, tenant=tenant)
        Membership.objects.get_or_create(
            user=user, role=invite.role, defaults={"job_title": invite.job_title}
        )

        invite.accepted_at = timezone.now()
        invite.save(update_fields=["accepted_at"])

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "user": UserSerializer(user).data,
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            },
            status=status.HTTP_201_CREATED,
        )
