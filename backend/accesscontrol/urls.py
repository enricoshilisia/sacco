from django.urls import path

from . import views

app_name = "accesscontrol"

urlpatterns = [
    path("me/", views.MyTenantProfileView.as_view(), name="my_tenant_profile"),
    path("profile/", views.TenantProfileUpdateView.as_view(), name="tenant_profile_update"),
    path("roles/", views.RoleListView.as_view(), name="role_list"),
    path("staff/", views.StaffListView.as_view(), name="staff_list"),
    path("staff/<uuid:pk>/", views.StaffMembershipUpdateView.as_view(), name="staff_update"),
    path("staff/invites/", views.StaffInviteListCreateView.as_view(), name="staff_invite_list_create"),
    path(
        "staff/invites/<uuid:pk>/revoke/",
        views.StaffInviteRevokeView.as_view(),
        name="staff_invite_revoke",
    ),
    path(
        "staff/invites/<str:token>/accept/",
        views.StaffInviteAcceptView.as_view(),
        name="staff_invite_accept",
    ),
]
