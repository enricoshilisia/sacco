from django.urls import path

from . import views

app_name = "configuration"

urlpatterns = [
    path("", views.TenantConfigView.as_view(), name="tenant_config"),
]
