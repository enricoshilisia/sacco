from django.urls import path

from . import views

app_name = "members"

urlpatterns = [
    path("", views.MemberListCreateView.as_view(), name="member_list_create"),
    path("me/", views.MyMemberView.as_view(), name="my_member"),
    path("me/photo/", views.MyMemberPhotoUploadView.as_view(), name="my_member_photo_upload"),
    path("portal-invites/", views.PortalInviteListView.as_view(), name="portal_invite_list"),
    path(
        "portal-invites/<uuid:pk>/revoke/",
        views.PortalInviteRevokeView.as_view(),
        name="portal_invite_revoke",
    ),
    path(
        "portal-invites/<str:token>/accept/",
        views.PortalInviteAcceptView.as_view(),
        name="portal_invite_accept",
    ),
    path("<uuid:pk>/", views.MemberDetailView.as_view(), name="member_detail"),
    path("<uuid:pk>/verify-kyc/", views.MemberKycVerifyView.as_view(), name="member_kyc_verify"),
    path("<uuid:pk>/photo/", views.MemberPhotoUploadView.as_view(), name="member_photo_upload"),
    path("<uuid:member_id>/portal-invite/", views.InvitePortalAccessView.as_view(), name="invite_portal_access"),
    path("guarantor-consents/", views.GuarantorConsentListCreateView.as_view(), name="guarantor_consent_list_create"),
    path("guarantor-consents/<uuid:pk>/respond/", views.GuarantorConsentRespondView.as_view(), name="guarantor_consent_respond"),
]
