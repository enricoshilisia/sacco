import csv
from datetime import datetime

from django.db.models import Q
from django.http import HttpResponse
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from accesscontrol.permissions import require_permission, user_has_permission

from .models import AuditEvent
from .serializers import AuditEventSerializer


def _parse_date(value):
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except (TypeError, ValueError):
        return None


class AuditEventListView(generics.ListAPIView):
    """
    The audit log, newest first. Filters: ?user=<id>, ?action=LOGIN|VIEW|...,
    ?area=members, ?q= (text in who/what/where/device/IP), ?from= / ?to=
    (YYYY-MM-DD), ?security=1 (sign-ins, failed sign-ins and security
    events only). ?export=csv downloads the filtered log (needs
    reports.export as well).
    """

    serializer_class = AuditEventSerializer
    permission_classes = [IsAuthenticated, require_permission("audit.view")]

    def get_queryset(self):
        params = self.request.query_params
        qs = AuditEvent.objects.all()
        if params.get("user"):
            qs = qs.filter(user_id=params["user"])
        if params.get("action"):
            qs = qs.filter(action=params["action"])
        if params.get("area"):
            qs = qs.filter(area=params["area"])
        if params.get("security") in ("1", "true"):
            qs = qs.filter(action__in=["LOGIN", "LOGIN_FAILED", "EVENT"])
        if params.get("q"):
            q = params["q"].strip()
            qs = qs.filter(
                Q(actor__icontains=q) | Q(summary__icontains=q) | Q(location__icontains=q)
                | Q(device__icontains=q) | Q(ip_address__startswith=q) | Q(target_label__icontains=q)
            )
        start, end = _parse_date(params.get("from")), _parse_date(params.get("to"))
        if start:
            qs = qs.filter(at__date__gte=start)
        if end:
            qs = qs.filter(at__date__lte=end)
        return qs

    def list(self, request, *args, **kwargs):
        if request.query_params.get("export") == "csv":
            if not user_has_permission(request.user, "reports.export"):
                return HttpResponse("You don't have the 'reports.export' permission.", status=403)
            response = HttpResponse(content_type="text/csv")
            response["Content-Disposition"] = 'attachment; filename="audit-log.csv"'
            writer = csv.writer(response)
            writer.writerow(["When", "Who", "Action", "What", "Record", "Result", "IP", "Location", "Device"])
            for e in self.get_queryset()[:50000]:
                writer.writerow([e.at.isoformat(), e.actor, e.get_action_display(), e.summary, e.target_label,
                                 e.status_code or "", e.ip_address or "", e.location, e.device])
            return response
        return super().list(request, *args, **kwargs)
