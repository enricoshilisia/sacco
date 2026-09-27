from datetime import date
from decimal import Decimal, InvalidOperation

from django.shortcuts import get_object_or_404
from rest_framework import generics, serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission, user_has_permission
from audit.services import record
from governance.models import Meeting
from members.models import Member

from . import services
from .models import Fine, FinePaymentMethod, FineStatus, OffenceType


def _bad(exc, code=status.HTTP_400_BAD_REQUEST):
    return Response({"detail": str(exc)}, status=code)


def _money(value, field="amount") -> Decimal:
    try:
        amount = Decimal(str(value))
    except (InvalidOperation, TypeError):
        raise ValueError(f"{field} must be a number.")
    return amount.quantize(Decimal("0.01"))


def _my_member(request):
    return Member.objects.filter(user=request.user).first()


class OffenceTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = OffenceType
        fields = ["id", "name", "amount", "description", "from_attendance", "is_active"]


class FineSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source="member.full_name", read_only=True)
    member_number = serializers.CharField(source="member.member_number", read_only=True)
    offence = serializers.CharField(source="offence_type.name", read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    outstanding = serializers.DecimalField(max_digits=18, decimal_places=2, read_only=True)
    meeting_title = serializers.CharField(source="meeting.title", read_only=True, default="")
    charged_by_name = serializers.SerializerMethodField()
    waived_by_name = serializers.SerializerMethodField()

    class Meta:
        model = Fine
        fields = [
            "id", "member", "member_name", "member_number", "offence_type", "offence", "amount", "paid",
            "outstanding", "status", "status_label", "incurred_on", "meeting", "meeting_title", "notes",
            "charged_by_name", "charged_at", "waived_by_name", "waived_at", "waived_reason",
        ]

    def get_charged_by_name(self, fine):
        return fine.charged_by.get_full_name() if fine.charged_by else ""

    def get_waived_by_name(self, fine):
        return fine.waived_by.get_full_name() if fine.waived_by else ""


FINES = Fine.objects.select_related("member", "offence_type", "meeting", "charged_by", "waived_by")


class OffenceTypeListCreateView(generics.ListCreateAPIView):
    """The rules and their amounts (fines.view; changing them needs
    fines.manage_rules)."""

    serializer_class = OffenceTypeSerializer
    queryset = OffenceType.objects.all()

    def get_permissions(self):
        code = "fines.manage_rules" if self.request.method == "POST" else "fines.view"
        return [IsAuthenticated(), require_permission(code)()]


class OffenceTypeDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = OffenceTypeSerializer
    queryset = OffenceType.objects.all()
    permission_classes = [IsAuthenticated, require_permission("fines.manage_rules")]


class FineListCreateView(APIView):
    """GET ?member=&status=&meeting= the fine register.
    POST {member, offence_type, incurred_on, amount?, meeting?, notes?}
    charges a fine (fines.charge)."""

    def get_permissions(self):
        code = "fines.charge" if self.request.method == "POST" else "fines.view"
        return [IsAuthenticated(), require_permission(code)()]

    def get(self, request):
        qs = FINES
        params = request.query_params
        if params.get("member"):
            qs = qs.filter(member_id=params["member"])
        if params.get("status"):
            qs = qs.filter(status=params["status"])
        if params.get("meeting"):
            qs = qs.filter(meeting_id=params["meeting"])
        if params.get("from"):
            qs = qs.filter(incurred_on__gte=params["from"])
        if params.get("to"):
            qs = qs.filter(incurred_on__lte=params["to"])
        return Response(FineSerializer(qs.order_by("-incurred_on", "-charged_at")[:500], many=True).data)

    def post(self, request):
        data = request.data
        member = get_object_or_404(Member, pk=data.get("member"))
        offence = get_object_or_404(OffenceType, pk=data.get("offence_type"))
        try:
            amount = _money(data["amount"]) if data.get("amount") not in (None, "") else None
            incurred_on = date.fromisoformat(data["incurred_on"]) if data.get("incurred_on") else date.today()
            meeting = Meeting.objects.filter(pk=data["meeting"]).first() if data.get("meeting") else None
            fine = services.charge_fine(
                member=member, offence_type=offence, amount=amount, incurred_on=incurred_on, meeting=meeting,
                notes=str(data.get("notes", "")), charged_by=request.user,
            )
        except (ValueError, InvalidOperation) as exc:
            return _bad(exc)
        record(request=request, event="fines.charged", area="fines",
               summary=f"Charged {member.full_name} {fine.amount} for {offence.name}", target=fine,
               target_label=member.full_name)
        return Response(FineSerializer(fine).data, status=status.HTTP_201_CREATED)


class BulkChargeView(APIView):
    """One sitting: {offence_type, incurred_on, notes?, meeting?, entries:
    [{member, amount?, notes?}]}. All or nothing."""

    permission_classes = [IsAuthenticated, require_permission("fines.charge")]

    def post(self, request):
        data = request.data
        offence = get_object_or_404(OffenceType, pk=data.get("offence_type"))
        try:
            incurred_on = date.fromisoformat(data["incurred_on"]) if data.get("incurred_on") else date.today()
            meeting = Meeting.objects.filter(pk=data["meeting"]).first() if data.get("meeting") else None
            entries = data.get("entries") or []
            for entry in entries:
                if entry.get("amount") not in (None, ""):
                    entry["amount"] = _money(entry["amount"])
            fines = services.charge_many(
                offence_type=offence, entries=entries, incurred_on=incurred_on, meeting=meeting,
                notes=str(data.get("notes", "")), charged_by=request.user,
            )
        except (ValueError, InvalidOperation) as exc:
            return _bad(exc)
        total = sum((f.amount for f in fines), Decimal("0"))
        record(request=request, event="fines.charged_many", area="fines",
               summary=f"Charged {len(fines)} members {total} for {offence.name}", target=offence,
               target_label=offence.name)
        return Response({"charged": len(fines), "total": str(total)}, status=status.HTTP_201_CREATED)


class FineWaiveView(APIView):
    permission_classes = [IsAuthenticated, require_permission("fines.waive")]

    def post(self, request, pk):
        fine = get_object_or_404(FINES, pk=pk)
        try:
            services.waive_fine(fine=fine, by=request.user, reason=str(request.data.get("reason", "")))
        except ValueError as exc:
            return _bad(exc)
        record(request=request, event="fines.waived", area="fines",
               summary=f"Waived {fine.amount} for {fine.member.full_name}: {fine.waived_reason}", target=fine,
               target_label=fine.member.full_name)
        return Response(FineSerializer(Fine.objects.get(pk=pk)).data)


class FinePaymentView(APIView):
    """POST {member, amount, method, paid_on, reference, idempotency_key}"""

    permission_classes = [IsAuthenticated, require_permission("fines.record_payment")]

    def post(self, request):
        data = request.data
        member = get_object_or_404(Member, pk=data.get("member"))
        try:
            key = str(data.get("idempotency_key", "")).strip()
            if not key:
                raise ValueError("idempotency_key is required.")
            method = data.get("method", FinePaymentMethod.CASH)
            if method not in FinePaymentMethod.values:
                raise ValueError("Method must be CASH, BANK or MOBILE_MONEY.")
            payment = services.record_payment(
                member=member, amount=_money(data.get("amount")), method=method,
                paid_on=date.fromisoformat(data["paid_on"]) if data.get("paid_on") else date.today(),
                idempotency_key=key, reference=str(data.get("reference", "")), recorded_by=request.user,
            )
        except (ValueError, InvalidOperation) as exc:
            return _bad(exc)
        record(request=request, event="fines.payment", area="fines",
               summary=f"Received {payment.amount} in fines from {member.full_name}", target=payment,
               target_label=member.full_name)
        return Response({"payment": str(payment.pk), **_member_payload(member)}, status=status.HTTP_201_CREATED)


def _member_payload(member) -> dict:
    summary = services.member_summary(member)
    return {
        "member": str(member.pk),
        "member_name": member.full_name,
        "member_number": member.member_number,
        **{k: (str(v) if isinstance(v, Decimal) else v) for k, v in summary.items()},
        "fines": FineSerializer(FINES.filter(member=member).order_by("-incurred_on"), many=True).data,
    }


class MyFinesView(APIView):
    """A member's own fines - no staff permission needed."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        member = _my_member(request)
        if member is None:
            return Response({"detail": "No member record is linked to this login."}, status=status.HTTP_404_NOT_FOUND)
        return Response(_member_payload(member))


class MemberFinesView(APIView):
    permission_classes = [IsAuthenticated, require_permission("fines.view")]

    def get(self, request, pk):
        return Response(_member_payload(get_object_or_404(Member, pk=pk)))


class FineSummaryView(APIView):
    """The register at a glance, plus who owes what (fines.view)."""

    permission_classes = [IsAuthenticated, require_permission("fines.view")]

    def get(self, request):
        from django.db.models import Count, Sum

        rows = (
            Fine.objects.exclude(status=FineStatus.WAIVED)
            .values("member_id", "member__member_number", "member__first_name", "member__other_names",
                    "member__last_name")
            .annotate(charged=Sum("amount"), paid=Sum("paid"), count=Count("id"))
            .order_by("member__member_number")
        )
        members = []
        totals = {"charged": Decimal("0"), "paid": Decimal("0"), "outstanding": Decimal("0")}
        for row in rows:
            charged, paid = row["charged"] or Decimal("0"), row["paid"] or Decimal("0")
            name = " ".join(filter(None, [row["member__first_name"], row["member__other_names"],
                                          row["member__last_name"]]))
            members.append({
                "member": str(row["member_id"]),
                "member_number": row["member__member_number"],
                "member_name": name,
                "charged": str(charged),
                "paid": str(paid),
                "outstanding": str(charged - paid),
                "count": row["count"],
            })
            totals["charged"] += charged
            totals["paid"] += paid
            totals["outstanding"] += charged - paid
        waived = Fine.objects.filter(status=FineStatus.WAIVED).aggregate(total=Sum("amount"))["total"] or Decimal("0")
        return Response({
            "members": members,
            "totals": {k: str(v) for k, v in totals.items()} | {"waived": str(waived)},
            "can_charge": user_has_permission(request.user, "fines.charge"),
            "can_record_payment": user_has_permission(request.user, "fines.record_payment"),
            "can_waive": user_has_permission(request.user, "fines.waive"),
        })


class MeetingFineProposalsView(APIView):
    """GET: who the register says should be fined for a meeting.
    POST {members: [id, ...]}: charge the confirmed ones (fines.charge)."""

    def get_permissions(self):
        code = "fines.charge" if self.request.method == "POST" else "fines.view"
        return [IsAuthenticated(), require_permission(code)()]

    def get(self, request, pk):
        meeting = get_object_or_404(Meeting.objects.prefetch_related("attendance__member"), pk=pk)
        return Response([
            {
                "member": str(row["member"].pk),
                "member_name": row["member"].full_name,
                "member_number": row["member"].member_number,
                "offence_type": str(row["offence_type"].pk),
                "offence": row["offence_type"].name,
                "amount": str(row["amount"]),
                "already_charged": row["already_charged"],
            }
            for row in services.proposals_from_meeting(meeting)
        ])

    def post(self, request, pk):
        meeting = get_object_or_404(Meeting.objects.prefetch_related("attendance__member"), pk=pk)
        members = request.data.get("members") or []
        try:
            charged = services.charge_from_meeting(meeting=meeting, member_ids=members, charged_by=request.user)
        except ValueError as exc:
            return _bad(exc)
        record(request=request, event="fines.charged_from_register", area="fines",
               summary=f"Charged {charged} fine(s) from the register of {meeting.title}", target=meeting,
               target_label=meeting.title)
        return Response({"charged": charged})
