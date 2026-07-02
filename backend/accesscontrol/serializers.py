from django.db import connection
from rest_framework import serializers

from identity.serializers import UserSerializer
from tenants.models import Tenant

from .models import Membership


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
            "created_at",
        ]


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
