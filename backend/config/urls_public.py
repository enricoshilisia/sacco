"""
URLconf used only for requests resolving to the public schema (i.e. a
hostname that doesn't match any tenant's Domain - see
SHOW_PUBLIC_IF_NO_TENANT_FOUND / PUBLIC_SCHEMA_URLCONF in settings.py).
Deliberately small: platform admin, SACCO sign-up, and SACCO lookup by
code (for the mobile app, which has no hostname to pick a tenant with -
see tenants.views.SaccoLookupView). Tenant-scoped concerns
(member login, business data) live in config/urls.py instead.
"""

from django.contrib import admin
from django.conf import settings
from django.urls import include, path, re_path
from django.views.static import serve

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/onboarding/", include("subscriptions.urls")),
    path("api/public/", include("tenants.urls")),
]

if settings.FILE_STORAGE == "local":
    # Uploaded files on local disk (see FILE_STORAGE in settings.py). Paths
    # include the member's random UUID, so they can't be guessed.
    urlpatterns.append(re_path(r"^media/(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}))
