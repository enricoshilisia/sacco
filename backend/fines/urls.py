from django.urls import path

from . import views

app_name = "fines"

urlpatterns = [
    path("", views.FineListCreateView.as_view(), name="fine_list_create"),
    path("me/", views.MyFinesView.as_view(), name="my_fines"),
    path("summary/", views.FineSummaryView.as_view(), name="summary"),
    path("payments/", views.FinePaymentView.as_view(), name="payment"),
    path("bulk/", views.BulkChargeView.as_view(), name="bulk_charge"),
    path("offence-types/", views.OffenceTypeListCreateView.as_view(), name="offence_type_list"),
    path("offence-types/<uuid:pk>/", views.OffenceTypeDetailView.as_view(), name="offence_type_detail"),
    path("members/<uuid:pk>/", views.MemberFinesView.as_view(), name="member_fines"),
    path("<uuid:pk>/waive/", views.FineWaiveView.as_view(), name="fine_waive"),
    path("meetings/<uuid:pk>/proposals/", views.MeetingFineProposalsView.as_view(), name="meeting_proposals"),
]
