from django.urls import path

from . import views

app_name = "members"

urlpatterns = [
    path("", views.MemberListCreateView.as_view(), name="member_list_create"),
    path("<uuid:pk>/", views.MemberDetailView.as_view(), name="member_detail"),
    path("<uuid:pk>/verify-kyc/", views.MemberKycVerifyView.as_view(), name="member_kyc_verify"),
    path("<uuid:pk>/photo/", views.MemberPhotoUploadView.as_view(), name="member_photo_upload"),
    path("guarantor-consents/", views.GuarantorConsentListCreateView.as_view(), name="guarantor_consent_list_create"),
    path("guarantor-consents/<uuid:pk>/respond/", views.GuarantorConsentRespondView.as_view(), name="guarantor_consent_respond"),
]
