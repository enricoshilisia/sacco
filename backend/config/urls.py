from django.contrib import admin
from django.conf import settings
from django.urls import include, path, re_path
from django.views.static import serve

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/auth/", include("identity.urls")),
    path("api/tenant/", include("accesscontrol.urls")),
    path("api/members/", include("members.urls")),
    path("api/settings/", include("configuration.urls")),
    path("api/accounting/", include("accounting.urls")),
    path("api/savings/", include("savings.urls")),
    path("api/payments/", include("payments.urls")),
    path("api/notifications/", include("notifications.urls")),
    path("api/loans/", include("loans.urls")),
    path("api/rules-engine/", include("rules_engine.urls")),
    path("api/distributions/", include("distributions.urls")),
    path("api/welfare/", include("welfare.urls")),
    path("api/reports/", include("reports.urls")),
    path("api/governance/", include("governance.urls")),
    path("i18n/", include("django.conf.urls.i18n")),
]

if settings.FILE_STORAGE == "local":
    # Uploaded files on local disk (see FILE_STORAGE in settings.py). Paths
    # include the member's random UUID, so they can't be guessed.
    urlpatterns.append(re_path(r"^media/(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}))
