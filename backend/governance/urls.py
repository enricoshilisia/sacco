from django.urls import path

from . import papers_views, views

app_name = "governance"

urlpatterns = [
    path("meetings/", views.MeetingListCreateView.as_view(), name="meeting_list_create"),
    path("meetings/<uuid:pk>/register/", views.MeetingRegisterView.as_view(), name="meeting_register"),
    path("meetings/<uuid:pk>/close/", views.CloseRegisterView.as_view(), name="close_register"),
    path("meetings/<uuid:pk>/cancel/", views.CancelMeetingView.as_view(), name="cancel_meeting"),
    path("meetings/<uuid:pk>/apology/", views.MyApologyView.as_view(), name="my_apology"),
    path("meetings/<uuid:pk>/documents/", papers_views.MeetingDocumentsView.as_view(), name="meeting_documents"),
    path("documents/<uuid:pk>/download/", papers_views.DocumentDownloadView.as_view(), name="document_download"),
    path("documents/<uuid:pk>/withdraw/", papers_views.DocumentWithdrawView.as_view(), name="document_withdraw"),
    path("meetings/<uuid:pk>/minutes/", papers_views.MinutesView.as_view(), name="minutes"),
    path("meetings/<uuid:pk>/minutes/submit/", papers_views.MinutesActionView.as_view(action="submit"),
         name="minutes_submit"),
    path("meetings/<uuid:pk>/minutes/approve/", papers_views.MinutesActionView.as_view(action="approve"),
         name="minutes_approve"),
    path("meetings/<uuid:pk>/minutes/return/", papers_views.MinutesActionView.as_view(action="return"),
         name="minutes_return"),
    path("meetings/<uuid:pk>/minutes/addendum/", papers_views.MinutesActionView.as_view(action="addendum"),
         name="minutes_addendum"),
    path("meetings/<uuid:pk>/minutes/pdf/", papers_views.MinutesPdfView.as_view(), name="minutes_pdf"),
    path("minutes/pending/", papers_views.MinutesQueueView.as_view(), name="minutes_pending"),
]
