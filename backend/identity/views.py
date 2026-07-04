from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from . import webauthn_service
from .models import PushDeviceToken, TenantAccess, User
from .serializers import TenantAccessSerializer, TenantScopedTokenObtainPairSerializer, UserSerializer


class TenantScopedTokenObtainPairView(TokenObtainPairView):
    serializer_class = TenantScopedTokenObtainPairSerializer


def _tokens_for(user):
    refresh = RefreshToken.for_user(user)
    return {"access": str(refresh.access_token), "refresh": str(refresh)}


def _assert_tenant_access(user):
    """Same rule as TenantScopedTokenObtainPairSerializer, for non-password login paths."""
    from django.db import connection
    from django_tenants.utils import get_public_schema_name

    if connection.schema_name == get_public_schema_name():
        return
    if not TenantAccess.objects.filter(user=user, tenant__schema_name=connection.schema_name, is_active=True).exists():
        raise ValueError("This account does not have access to this SACCO.")


def _grant_default_tenant_membership(user):
    """
    Grants the default "Member" role + TenantAccess for this tenant. Only
    ever called from within a tenant's own urlconf (never the public one -
    see config/urls_public.py), so connection.schema_name here is always a
    real SACCO, never the public schema. Used by
    members.views.PortalInviteAcceptView - there's no open self-registration
    path anymore (members don't create their own accounts; a real
    cooperative registers the member first, on paper or by staff, and
    grants portal access as a separate, later step - see
    members.MemberPortalInvite).
    """
    from django.db import connection

    from accesscontrol.models import Membership, Role
    from tenants.models import Tenant

    tenant = Tenant.objects.get(schema_name=connection.schema_name)
    TenantAccess.objects.get_or_create(user=user, tenant=tenant)
    member_role = Role.objects.get(name="Member")
    Membership.objects.get_or_create(user=user, role=member_role)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        tenant_access = TenantAccess.objects.filter(user=request.user, is_active=True)
        return Response(
            {
                "user": UserSerializer(request.user).data,
                "tenants": TenantAccessSerializer(tenant_access, many=True).data,
            }
        )


class ChangePasswordView(APIView):
    """
    Every logged-in user (staff or self-service member alike) can change
    their own password - this is a User-level action in the shared/public
    schema, not tied to any tenant permission catalog, so ownership (must
    know the current password) is the only check. Distinct from the
    one-time password *set* during portal/invite acceptance
    (members.views.PortalInviteAcceptView) which has no "current password"
    to verify yet.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        current_password = request.data.get("current_password", "")
        new_password = request.data.get("new_password", "")
        if not request.user.check_password(current_password):
            return Response({"detail": "Current password is incorrect."}, status=status.HTTP_400_BAD_REQUEST)
        if len(new_password) < 8:
            return Response({"detail": "New password must be at least 8 characters."}, status=status.HTTP_400_BAD_REQUEST)
        request.user.set_password(new_password)
        request.user.save(update_fields=["password"])
        return Response(status=status.HTTP_204_NO_CONTENT)


class WebAuthnRegistrationOptionsView(APIView):
    """Start enrolling a new biometric credential for the logged-in user."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        options_json = webauthn_service.build_registration_options(request.user)
        return Response(data=options_json, content_type="application/json")


class WebAuthnRegistrationVerifyView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        device_name = request.data.get("device_name", "")
        try:
            credential = webauthn_service.verify_registration(
                request.user, request.data.get("credential"), device_name
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"id": str(credential.id), "device_name": credential.device_name})


class WebAuthnAuthenticationOptionsView(APIView):
    """
    Start a passwordless login. Caller identifies themselves by phone_number
    first (non-discoverable-credential flow) so we know which credentials to
    allow.
    """

    permission_classes = [AllowAny]

    def post(self, request):
        phone_number = request.data.get("phone_number")
        user = get_object_or_404(User, phone_number=phone_number)
        options_json = webauthn_service.build_authentication_options(user)
        return Response(data=options_json, content_type="application/json")


class WebAuthnAuthenticationVerifyView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone_number = request.data.get("phone_number")
        user = get_object_or_404(User, phone_number=phone_number)
        try:
            webauthn_service.verify_authentication(user, request.data.get("credential"))
            _assert_tenant_access(user)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"user": UserSerializer(user).data, **_tokens_for(user)})


class PushDeviceTokenView(APIView):
    """Register/refresh this device's Firebase Cloud Messaging token."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        token = request.data.get("token")
        platform = request.data.get("platform", "web")
        if not token:
            return Response({"detail": "token is required"}, status=status.HTTP_400_BAD_REQUEST)
        PushDeviceToken.objects.update_or_create(
            token=token,
            defaults={"user": request.user, "platform": platform, "is_active": True},
        )
        return Response(status=status.HTTP_204_NO_CONTENT)

    def delete(self, request):
        token = request.data.get("token")
        PushDeviceToken.objects.filter(user=request.user, token=token).update(is_active=False)
        return Response(status=status.HTTP_204_NO_CONTENT)
