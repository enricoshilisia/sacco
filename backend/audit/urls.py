from django.urls import path

from . import views

app_name = "audit"

urlpatterns = [
    path("events/", views.AuditEventListView.as_view(), name="event_list"),
]
