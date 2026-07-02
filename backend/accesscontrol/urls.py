from django.urls import path

from . import views

app_name = "accesscontrol"

urlpatterns = [
    path("me/", views.MyTenantProfileView.as_view(), name="my_tenant_profile"),
    path("profile/", views.TenantProfileUpdateView.as_view(), name="tenant_profile_update"),
]
