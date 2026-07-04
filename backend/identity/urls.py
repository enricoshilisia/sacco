from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from . import views

app_name = "identity"

urlpatterns = [
    path("token/", views.TenantScopedTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("me/", views.MeView.as_view(), name="me"),
    path("me/change-password/", views.ChangePasswordView.as_view(), name="change_password"),
    path("webauthn/register/options/", views.WebAuthnRegistrationOptionsView.as_view(), name="webauthn_register_options"),
    path("webauthn/register/verify/", views.WebAuthnRegistrationVerifyView.as_view(), name="webauthn_register_verify"),
    path("webauthn/authenticate/options/", views.WebAuthnAuthenticationOptionsView.as_view(), name="webauthn_auth_options"),
    path("webauthn/authenticate/verify/", views.WebAuthnAuthenticationVerifyView.as_view(), name="webauthn_auth_verify"),
    path("push/devices/", views.PushDeviceTokenView.as_view(), name="push_device_token"),
]
