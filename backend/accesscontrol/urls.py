from django.urls import path

from . import support_views, views

app_name = "accesscontrol"

urlpatterns = [
    path("users/", support_views.UserListView.as_view(), name="user_list"),
    path("users/<uuid:pk>/", support_views.UserDetailView.as_view(), name="user_detail"),
    path("users/<uuid:pk>/positions/", support_views.UserPositionsView.as_view(), name="user_positions"),
    path("users/<uuid:pk>/reset-password/", support_views.ResetPasswordView.as_view(), name="user_reset_password"),
    path("users/<uuid:pk>/disable/", support_views.LoginEnabledView.as_view(enabled=False), name="user_disable"),
    path("users/<uuid:pk>/enable/", support_views.LoginEnabledView.as_view(enabled=True), name="user_enable"),
    path("positions/", support_views.PositionListCreateView.as_view(), name="position_list"),
    path("positions/<uuid:pk>/assign/", support_views.PositionAssignView.as_view(), name="position_assign"),
    path("memberships/<uuid:pk>/remove/", support_views.MembershipRemoveView.as_view(), name="membership_remove"),
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
