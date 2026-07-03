from django.db import connection
from rest_framework import serializers

from identity.serializers import UserSerializer
from tenants.models import Tenant

from .models import Membership, Role, StaffInvite


class TenantProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tenant
        fields = [
            "name",
            "country",
            "currency",
            "default_language",
            "address",
            "contact_email",
            "contact_phone",
            "logo",
            "created_at",
        ]


class TenantUpdateSerializer(serializers.ModelSerializer):
    """
    Editing a SACCO's own profile after creation - name, contact details,
    and logo. Deliberately excludes country/currency: those are set once at
    sign-up and changing them afterwards has real regulatory/accounting
    implications, not just a display update.
    """

    class Meta:
        model = Tenant
        fields = ["name", "address", "contact_email", "contact_phone", "logo"]


class MembershipSerializer(serializers.ModelSerializer):
    role_name = serializers.CharField(source="role.name", read_only=True)

    class Meta:
        model = Membership
        fields = ["role_name", "job_title", "is_active", "assigned_at"]


class MyTenantProfileSerializer(serializers.Serializer):
    """Combined view: this SACCO's profile + the requesting user's role(s) in it."""

    tenant = serializers.SerializerMethodField()
    user = serializers.SerializerMethodField()
    memberships = serializers.SerializerMethodField()

    def get_tenant(self, request):
        tenant = Tenant.objects.get(schema_name=connection.schema_name)
        return TenantProfileSerializer(tenant).data

    def get_user(self, request):
        return UserSerializer(request.user).data

    def get_memberships(self, request):
        memberships = Membership.objects.filter(user=request.user, is_active=True).select_related("role")
        return MembershipSerializer(memberships, many=True).data


class RoleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Role
        fields = ["id", "name", "description"]


class StaffMembershipSerializer(serializers.ModelSerializer):
    """One row of the staff/governance roster - a Membership joined out to
    the (cross-schema, public) User it belongs to."""

    user_id = serializers.UUIDField(source="user.id", read_only=True)
    first_name = serializers.CharField(source="user.first_name", read_only=True)
    last_name = serializers.CharField(source="user.last_name", read_only=True)
    phone_number = serializers.CharField(source="user.phone_number", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)
    role_name = serializers.CharField(source="role.name", read_only=True)

    class Meta:
        model = Membership
        fields = [
            "id", "user_id", "first_name", "last_name", "phone_number", "email",
            "role", "role_name", "job_title", "is_active", "assigned_at",
        ]
        read_only_fields = ["id", "assigned_at"]


class StaffInviteSerializer(serializers.ModelSerializer):
    role_name = serializers.CharField(source="role.name", read_only=True)
    status = serializers.CharField(read_only=True)
    invite_path = serializers.SerializerMethodField()

    class Meta:
        model = StaffInvite
        fields = [
            "id", "token", "phone_number", "email", "first_name", "last_name",
            "job_title", "role", "role_name", "status", "created_at",
            "expires_at", "invite_path",
        ]
        read_only_fields = ["id", "token", "status", "created_at", "expires_at"]

    def get_invite_path(self, obj) -> str:
        return f"/staff/accept/{obj.token}"
