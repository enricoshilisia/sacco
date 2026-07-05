from django.contrib import admin
from django.urls import include, path

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
    path("i18n/", include("django.conf.urls.i18n")),
]
