from django.urls import path

from . import views

app_name = "governance"

urlpatterns = [
    path("meetings/", views.MeetingListCreateView.as_view(), name="meeting_list_create"),
    path("meetings/<uuid:pk>/register/", views.MeetingRegisterView.as_view(), name="meeting_register"),
    path("meetings/<uuid:pk>/close/", views.CloseRegisterView.as_view(), name="close_register"),
    path("meetings/<uuid:pk>/cancel/", views.CancelMeetingView.as_view(), name="cancel_meeting"),
    path("meetings/<uuid:pk>/apology/", views.MyApologyView.as_view(), name="my_apology"),
]
