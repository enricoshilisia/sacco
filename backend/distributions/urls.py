from django.urls import path

from . import views

app_name = "distributions"

urlpatterns = [
    path("me/", views.MyDistributionsListView.as_view(), name="my_distributions"),
    path("runs/", views.DistributionRunListView.as_view(), name="run_list"),
    path("runs/dividend/", views.ProposeDividendRunView.as_view(), name="propose_dividend"),
    path("runs/interest/", views.ProposeInterestRunView.as_view(), name="propose_interest"),
    path("runs/<uuid:pk>/", views.DistributionRunDetailView.as_view(), name="run_detail"),
    path("runs/<uuid:pk>/approve/", views.ApproveDistributionRunView.as_view(), name="approve_run"),
    path("runs/<uuid:pk>/reject/", views.RejectDistributionRunView.as_view(), name="reject_run"),
    path("runs/<uuid:pk>/payout-all/", views.PayoutAllView.as_view(), name="payout_all"),
    path("entries/<uuid:pk>/payout/", views.InitiateDistributionPayoutView.as_view(), name="initiate_payout"),
]
