"""New members: applications (Secretary registers, Chairperson approves),
registration fees, verification status and the membership rules."""

from datetime import date

from django.shortcuts import get_object_or_404
from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission, user_has_permission
from audit.services import record

from . import admission
from .models import Member, MemberApplication, MembershipSettings, PaymentMethod


class ApplicationSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    submitted_by_name = serializers.SerializerMethodField()
    decided_by_name = serializers.SerializerMethodField()
    member_number = serializers.CharField(source="member.member_number", read_only=True, default="")
    member_id = serializers.UUIDField(source="member.id", read_only=True, default=None)

    class Meta:
        model = MemberApplication
        fields = [
            "id", "status", "status_label", "full_name",
            "first_name", "last_name", "other_names", "date_of_birth", "gender", "id_type", "id_number",
            "phone_number", "email", "physical_address", "marital_status", "occupation", "employer", "county",
            "notes", "fee_collected", "fee_method", "fee_reference",
            "submitted_by", "submitted_by_name", "submitted_at",
            "decided_by", "decided_by_name", "decided_at", "decision_notes", "member_id", "member_number",
        ]
        read_only_fields = [
            "id", "status", "submitted_by", "submitted_at", "decided_by", "decided_at", "decision_notes",
        ]

    def get_submitted_by_name(self, obj):
        return obj.submitted_by.get_full_name() if obj.submitted_by else ""

    def get_decided_by_name(self, obj):
        return obj.decided_by.get_full_name() if obj.decided_by else ""


def _bad(exc):
    return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)


class ApplicationListCreateView(APIView):
    """GET ?status=PENDING|APPROVED|REJECTED|CANCELLED (register or approve
    permission). POST registers a new applicant (members.register)."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not (user_has_permission(request.user, "members.register")
                or user_has_permission(request.user, "members.approve_admission")):
            return Response({"detail": "You can't see member applications."}, status=status.HTTP_403_FORBIDDEN)
        qs = MemberApplication.objects.select_related("submitted_by", "decided_by", "member")
        if request.query_params.get("status"):
            qs = qs.filter(status=request.query_params["status"])
        return Response(ApplicationSerializer(qs[:200], many=True).data)

    def post(self, request):
        if not user_has_permission(request.user, "members.register"):
            return Response({"detail": "You can't register new members."}, status=status.HTTP_403_FORBIDDEN)
        serializer = ApplicationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = {k: v for k, v in serializer.validated_data.items() if k in {f.name for f in MemberApplication._meta.fields}}
        try:
            application = admission.submit_application(data=data, submitted_by=request.user)
        except ValueError as exc:
            return _bad(exc)
        record(request=request, event="members.application_submitted", area="members",
               summary=f"Registered applicant {application.full_name}", target=application,
               target_label=application.full_name)
        return Response(ApplicationSerializer(application).data, status=status.HTTP_201_CREATED)


class ApplicationDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        if not (user_has_permission(request.user, "members.register")
                or user_has_permission(request.user, "members.approve_admission")):
            return Response({"detail": "You can't see member applications."}, status=status.HTTP_403_FORBIDDEN)
        return Response(ApplicationSerializer(get_object_or_404(MemberApplication, pk=pk)).data)


class ApplicationDecisionView(APIView):
    permission_classes = [IsAuthenticated, require_permission("members.approve_admission")]
    approve = True

    def post(self, request, pk):
        application = get_object_or_404(MemberApplication, pk=pk)
        notes = str(request.data.get("notes", "") or request.data.get("reason", ""))
        try:
            if self.approve:
                application, temporary = admission.approve_application(application, by=request.user, notes=notes)
            else:
                application, temporary = admission.reject_application(application, by=request.user, reason=notes), None
        except ValueError as exc:
            return _bad(exc)
        record(request=request, event="members.application_" + ("approved" if self.approve else "rejected"),
               area="members",
               summary=f"{'Approved' if self.approve else 'Rejected'} the application of {application.full_name}",
               target=application, target_label=application.full_name)
        data = ApplicationSerializer(application).data
        # Shown once, for the approver to hand to the new member.
        data["temporary_password"] = temporary
        return Response(data)


class ApplicationCancelView(APIView):
    permission_classes = [IsAuthenticated, require_permission("members.register")]

    def post(self, request, pk):
        try:
            application = admission.cancel_application(get_object_or_404(MemberApplication, pk=pk), by=request.user)
        except ValueError as exc:
            return _bad(exc)
        return Response(ApplicationSerializer(application).data)


class RegistrationFeeView(APIView):
    """POST {amount, method, reference, paid_on, idempotency_key} records a
    registration fee received at the counter / by bank."""

    permission_classes = [IsAuthenticated, require_permission("members.record_fee")]

    def post(self, request, pk):
        from decimal import Decimal, InvalidOperation

        member = get_object_or_404(Member, pk=pk)
        try:
            amount = Decimal(str(request.data.get("amount")))
            method = request.data.get("method", PaymentMethod.CASH)
            if method not in PaymentMethod.values:
                raise ValueError("Method must be CASH, BANK or MOBILE_MONEY.")
            key = str(request.data.get("idempotency_key", "")).strip()
            if not key:
                raise ValueError("idempotency_key is required.")
            paid_on = date.fromisoformat(request.data["paid_on"]) if request.data.get("paid_on") else date.today()
            admission.record_registration_fee(
                member=member, amount=amount, method=method, reference=request.data.get("reference", ""),
                paid_on=paid_on, idempotency_key=key, recorded_by=request.user,
            )
        except (ValueError, InvalidOperation) as exc:
            return _bad(exc)
        return Response(_status_json(Member.objects.get(pk=member.pk)))


def _status_json(member):
    from decimal import Decimal

    s = admission.verification_status(member)
    money = ("registration_fee", "fee_paid", "fee_outstanding")
    return {k: (str(Decimal(v)) if k in money else v) for k, v in s.items()}


class MemberVerificationView(APIView):
    permission_classes = [IsAuthenticated, require_permission("members.view")]

    def get(self, request, pk):
        return Response(_status_json(get_object_or_404(Member, pk=pk)))


class MyVerificationView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        member = Member.objects.filter(user=request.user).first()
        if member is None:
            return Response({"detail": "No member record is linked to this login."}, status=status.HTTP_404_NOT_FOUND)
        return Response(_status_json(member))


class MembershipSettingsView(APIView):
    """GET for anyone signed in (the app shows the fee); PATCH needs
    configuration.edit."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        s = MembershipSettings.get_solo()
        return Response({"registration_fee": str(s.registration_fee), "verification_months": s.verification_months})

    def patch(self, request):
        from decimal import Decimal, InvalidOperation

        if not user_has_permission(request.user, "configuration.edit"):
            return Response({"detail": "You can't change membership rules."}, status=status.HTTP_403_FORBIDDEN)
        s = MembershipSettings.get_solo()
        try:
            if "registration_fee" in request.data:
                fee = Decimal(str(request.data["registration_fee"]))
                if fee < 0:
                    raise ValueError("The fee can't be negative.")
                s.registration_fee = fee
            if "verification_months" in request.data:
                months = int(request.data["verification_months"])
                if not 1 <= months <= 24:
                    raise ValueError("Months must be between 1 and 24.")
                s.verification_months = months
        except (ValueError, InvalidOperation) as exc:
            return _bad(exc)
        s.save()
        record(request=request, event="settings.membership", area="settings",
               summary=f"Set registration fee {s.registration_fee}, verification after {s.verification_months} months")
        return self.get(request)
