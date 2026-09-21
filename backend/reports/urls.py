from django.urls import path

from . import views

app_name = "reports"

urlpatterns = [
    path("", views.ReportCatalogView.as_view(), name="catalog"),
    path("summary/", views.FinanceSummaryView.as_view(), name="finance_summary"),
    path("my-tasks/", views.MyTasksView.as_view(), name="my_tasks"),
    path("<str:key>/", views.ReportView.as_view(), name="report"),
]
