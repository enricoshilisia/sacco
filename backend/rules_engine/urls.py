from django.urls import path

from . import views

app_name = "rules_engine"

urlpatterns = [
    path(
        "loan-products/<uuid:product_id>/eligibility-policy/",
        views.LoanEligibilityPolicyView.as_view(),
        name="loan_product_eligibility_policy",
    ),
]
