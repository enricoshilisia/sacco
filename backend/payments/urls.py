from django.urls import path

from . import views

app_name = "payments"

urlpatterns = [
    path("members/<uuid:member_id>/collect/", views.InitiateCollectionView.as_view(), name="initiate_collection"),
    path("collections/", views.CollectionListView.as_view(), name="collection_list"),
    path("collections/<uuid:pk>/", views.CollectionDetailView.as_view(), name="collection_detail"),
    path("callbacks/mpesa/", views.MpesaCallbackView.as_view(), name="mpesa_callback"),
    path("callbacks/selcom/", views.SelcomCallbackView.as_view(), name="selcom_callback"),
    path("callbacks/mock/", views.MockCallbackView.as_view(), name="mock_callback"),
    path(
        "callbacks/mock/loan-disbursement/",
        views.MockLoanDisbursementCallbackView.as_view(),
        name="mock_loan_disbursement_callback",
    ),
]
