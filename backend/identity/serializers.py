from django.db import connection
from django_tenants.utils import get_public_schema_name
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import TenantAccess, User


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            "id",
            "phone_number",
            "email",
            "first_name",
            "last_name",
            "preferred_language",
            "is_phone_verified",
        ]
        read_only_fields = ["id", "is_phone_verified"]


class TenantAccessSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source="tenant.name", read_only=True)
    tenant_schema = serializers.CharField(source="tenant.schema_name", read_only=True)
    country = serializers.CharField(source="tenant.country", read_only=True)

    class Meta:
        model = TenantAccess
        fields = ["tenant_name", "tenant_schema", "country", "is_active", "joined_at"]


class TenantScopedTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    Identity (the User table) is shared across all SACCOs, but a login on a
    given SACCO's domain must not succeed unless that user actually belongs
    to that SACCO. Without this check, credentials valid on one tenant's
    domain would silently work on every other tenant's domain too.
    """

    def validate(self, attrs):
        from subscriptions.models import Subscription

        data = super().validate(attrs)
        if connection.schema_name != get_public_schema_name():
            has_access = TenantAccess.objects.filter(
                user=self.user,
                tenant__schema_name=connection.schema_name,
                is_active=True,
            ).exists()
            if not has_access:
                raise serializers.ValidationError(
                    "This account does not have access to this SACCO."
                )

            subscription = Subscription.objects.filter(
                tenant__schema_name=connection.schema_name
            ).first()
            if subscription is not None and not subscription.is_usable:
                raise serializers.ValidationError(
                    "This SACCO's free trial has ended. Contact the platform "
                    "operator to activate a paid plan."
                )
        return data
