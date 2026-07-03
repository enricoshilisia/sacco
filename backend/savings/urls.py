from django.urls import path

from . import views

app_name = "savings"

urlpatterns = [
    path("products/", views.SavingsProductListCreateView.as_view(), name="product_list_create"),
    path("me/statement/", views.MyStatementView.as_view(), name="my_statement"),
    path("members/<uuid:member_id>/statement/", views.MemberStatementView.as_view(), name="member_statement"),
    path(
        "members/<uuid:member_id>/shares/contribute/",
        views.ContributeSharesView.as_view(),
        name="contribute_shares",
    ),
    path("members/<uuid:member_id>/deposit/", views.DepositSavingsView.as_view(), name="deposit_savings"),
    path("members/<uuid:member_id>/withdraw/", views.WithdrawSavingsView.as_view(), name="withdraw_savings"),
]
