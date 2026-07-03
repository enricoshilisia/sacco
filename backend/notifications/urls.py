from django.urls import path

from . import views

app_name = "notifications"

urlpatterns = [
    path("log/", views.NotificationLogListView.as_view(), name="log_list"),
]
