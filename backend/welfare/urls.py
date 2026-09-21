from django.urls import path

from . import views

app_name = "welfare"

urlpatterns = [
    path("settings/", views.WelfareSettingsView.as_view(), name="settings"),
    path("case-types/", views.CaseTypeListCreateView.as_view(), name="case_type_list_create"),
    path("case-types/<uuid:pk>/", views.CaseTypeDetailView.as_view(), name="case_type_detail"),
    path("cases/", views.CaseListCreateView.as_view(), name="case_list_create"),
    path("cases/<uuid:pk>/", views.CaseDetailView.as_view(), name="case_detail"),
    path("cases/<uuid:pk>/contributions/", views.CaseContributionsView.as_view(), name="case_contributions"),
    path("cases/<uuid:pk>/approve/", views.ApproveCaseView.as_view(), name="approve_case"),
    path("cases/<uuid:pk>/reject/", views.RejectCaseView.as_view(), name="reject_case"),
    path("cases/<uuid:pk>/close/", views.CloseCaseView.as_view(), name="close_case"),
    path("cases/<uuid:pk>/payouts/", views.RecordPayoutView.as_view(), name="record_payout"),
    path("members/search/", views.MemberSearchView.as_view(), name="member_search"),
    path("members/<uuid:member_id>/", views.MemberWelfareView.as_view(), name="member_welfare"),
    path("members/<uuid:member_id>/family/", views.MemberFamilyForCaseView.as_view(), name="member_family"),
    path("members/<uuid:member_id>/payments/", views.RecordMemberPaymentView.as_view(), name="record_payment"),
    path("me/", views.MyWelfareView.as_view(), name="my_welfare"),
    path("years/", views.YearCloseListView.as_view(), name="year_close_list"),
    path("years/<int:year>/close/", views.CloseYearView.as_view(), name="close_year"),
]
