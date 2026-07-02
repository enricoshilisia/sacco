from django.urls import path

from . import views

app_name = "subscriptions"

urlpatterns = [
    path("signup/", views.SaccoSignupView.as_view(), name="signup"),
]
