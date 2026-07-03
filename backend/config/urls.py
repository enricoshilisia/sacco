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
    path("i18n/", include("django.conf.urls.i18n")),
]
