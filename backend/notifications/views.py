from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from accesscontrol.permissions import require_permission

from .models import NotificationLog
from .serializers import NotificationLogSerializer


class NotificationLogListView(generics.ListAPIView):
    queryset = NotificationLog.objects.select_related("member").all()
    serializer_class = NotificationLogSerializer
    permission_classes = [IsAuthenticated, require_permission("reports.view")]
