from django.urls import path

from . import views

app_name = "accounting"

urlpatterns = [
    path("trial-balance/", views.TrialBalanceView.as_view(), name="trial_balance"),
    path("journal-entries/", views.JournalEntryListView.as_view(), name="journal_entry_list"),
    path(
        "journal-entries/<uuid:pk>/reverse/",
        views.JournalEntryReverseView.as_view(),
        name="journal_entry_reverse",
    ),
]
