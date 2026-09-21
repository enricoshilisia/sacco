from django.urls import path

from . import views

app_name = "tenants"

urlpatterns = [
    path("saccos/<str:code>/", views.SaccoLookupView.as_view(), name="sacco_lookup"),
]
