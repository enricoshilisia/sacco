"""
URLconf used only for requests resolving to the public schema (i.e. a
hostname that doesn't match any tenant's Domain - see
SHOW_PUBLIC_IF_NO_TENANT_FOUND / PUBLIC_SCHEMA_URLCONF in settings.py).
Deliberately small: platform admin + SACCO sign-up. Tenant-scoped concerns
(member login, business data) live in config/urls.py instead.
"""

from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/onboarding/", include("subscriptions.urls")),
]
