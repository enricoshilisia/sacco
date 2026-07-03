from django.urls import path

from . import views

app_name = "loans"

urlpatterns = [
    path("products/", views.LoanProductListCreateView.as_view(), name="product_list_create"),
    path("me/", views.MyLoansListView.as_view(), name="my_loans"),
    path("me/apply/", views.MyLoanApplyView.as_view(), name="my_apply"),
    path("me/guarantee-requests/", views.MyGuaranteeRequestsView.as_view(), name="my_guarantee_requests"),
    path("members/<uuid:member_id>/apply/", views.LoanApplyOnBehalfView.as_view(), name="apply_on_behalf"),
    path("guarantors/<uuid:pk>/respond/", views.RespondToGuaranteeView.as_view(), name="respond_to_guarantee"),
    path("", views.LoanListView.as_view(), name="loan_list"),
    path("<uuid:pk>/", views.LoanDetailView.as_view(), name="loan_detail"),
    path("<uuid:loan_id>/guarantors/", views.AddLoanGuarantorView.as_view(), name="add_guarantor"),
    path("<uuid:pk>/submit/", views.SubmitForAppraisalView.as_view(), name="submit_for_appraisal"),
    path("<uuid:pk>/appraise/", views.AppraiseLoanView.as_view(), name="appraise"),
    path("<uuid:pk>/decide/", views.DecideLoanView.as_view(), name="decide"),
]
