from django_tenants.utils import schema_context
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.models import Membership, Role
from identity.models import TenantAccess, User
from tenants.services import provision_tenant, unique_schema_and_domain

from .models import Plan, Subscription
from .serializers import SaccoSignupSerializer


class SaccoSignupView(APIView):
    """
    Public (no auth) - create a brand new SACCO with a 30-day free trial and
    its first user (SuperAdmin). Only reachable via the public-schema
    urlconf (see config/urls_public.py) - a hostname that doesn't match any
    tenant's domain, e.g. plain "localhost" in dev.
    """

    permission_classes = [AllowAny]

    def post(self, request):
        serializer = SaccoSignupSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        schema_name, domain = unique_schema_and_domain(data["sacco_name"])
        tenant = provision_tenant(
            name=data["sacco_name"],
            schema_name=schema_name,
            domain=domain,
            country=data["country"],
        )

        default_plan = Plan.objects.filter(is_default=True, is_active=True).first()
        subscription = Subscription.objects.create(
            tenant=tenant,
            plan=default_plan,
            status=Subscription.TRIALING,
            trial_ends_at=Subscription.default_trial_end(),
        )

        owner = User.objects.create_user(
            phone_number=data["phone_number"],
            password=data["password"],
            first_name=data["first_name"],
            last_name=data["last_name"],
            preferred_language=tenant.default_language,
        )
        TenantAccess.objects.create(user=owner, tenant=tenant)

        with schema_context(tenant.schema_name):
            super_admin_role = Role.objects.get(name="SuperAdmin")
            Membership.objects.create(user=owner, role=super_admin_role)

        return Response(
            {
                "sacco_name": tenant.name,
                "country": tenant.country,
                "domain": domain,
                "trial_ends_at": subscription.trial_ends_at,
                "status": subscription.status,
            },
            status=status.HTTP_201_CREATED,
        )
