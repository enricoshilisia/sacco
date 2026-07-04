from decimal import Decimal

from rest_framework import serializers

from members.models import Member
from savings.models import SavingsProduct

from .models import Loan, LoanGuarantor, LoanProduct, LoanRepayment, LoanRepaymentSchedule
from .services import get_arrears_status


class LoanProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = LoanProduct
        fields = [
            "id", "name", "code", "interest_method", "interest_rate",
            "min_term_months", "max_term_months", "max_multiple_of_deposits",
            "requires_guarantors", "min_guarantors", "is_active",
        ]


class LoanGuarantorSerializer(serializers.ModelSerializer):
    guarantor_name = serializers.CharField(source="guarantor.full_name", read_only=True)
    guarantor_member_number = serializers.CharField(source="guarantor.member_number", read_only=True)
    borrower_name = serializers.CharField(source="loan.member.full_name", read_only=True)

    class Meta:
        model = LoanGuarantor
        fields = [
            "id", "loan", "guarantor", "guarantor_name", "guarantor_member_number", "borrower_name",
            "pledged_amount", "status", "requested_at", "responded_at", "released_at",
        ]
        read_only_fields = ["id", "status", "requested_at", "responded_at", "released_at"]


class LoanRepaymentScheduleSerializer(serializers.ModelSerializer):
    total_due = serializers.DecimalField(max_digits=18, decimal_places=2, read_only=True)
    is_paid = serializers.BooleanField(read_only=True)

    class Meta:
        model = LoanRepaymentSchedule
        fields = [
            "id", "installment_number", "due_date", "principal_due", "interest_due",
            "principal_paid", "interest_paid", "total_due", "is_paid",
        ]


class LoanRepaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = LoanRepayment
        fields = ["id", "amount", "transaction_date", "created_at", "description"]


class LoanSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source="member.full_name", read_only=True)
    member_number = serializers.CharField(source="member.member_number", read_only=True)
    product_name = serializers.CharField(source="product.name", read_only=True)
    guarantors = LoanGuarantorSerializer(many=True, read_only=True)
    appraised_by_name = serializers.CharField(source="appraised_by.get_full_name", read_only=True, default=None)
    decided_by_name = serializers.CharField(source="decided_by.get_full_name", read_only=True, default=None)
    schedule = LoanRepaymentScheduleSerializer(many=True, read_only=True)
    repayments = LoanRepaymentSerializer(many=True, read_only=True)
    outstanding_balance = serializers.SerializerMethodField()
    arrears = serializers.SerializerMethodField()

    class Meta:
        model = Loan
        fields = [
            "id", "member", "member_name", "member_number", "product", "product_name",
            "amount_requested", "term_months", "purpose", "interest_method", "interest_rate",
            "status", "applied_at", "appraised_at", "appraised_by_name", "appraisal_notes",
            "decided_at", "decided_by_name", "decision_notes", "guarantors",
            "disbursed_at", "disbursement_method", "closed_at", "defaulted_at", "default_notes",
            "schedule", "repayments", "outstanding_balance", "arrears",
        ]

    def get_outstanding_balance(self, loan):
        return sum(
            (row.total_due - row.principal_paid - row.interest_paid for row in loan.schedule.all()),
            Decimal("0"),
        )

    def get_arrears(self, loan):
        return get_arrears_status(loan)


class LoanApplyInputSerializer(serializers.Serializer):
    product = serializers.PrimaryKeyRelatedField(queryset=LoanProduct.objects.filter(is_active=True))
    amount_requested = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0.01"))
    term_months = serializers.IntegerField(min_value=1)
    purpose = serializers.CharField(required=False, allow_blank=True, default="")


class AddGuarantorInputSerializer(serializers.Serializer):
    # Staff (who hold members.view) pick from the full member list via
    # `guarantor`; a self-service borrower doesn't have members.view (that's
    # a staff "look up any member" permission, deliberately not on the
    # default "Member" role - see accesscontrol/migrations/0006/0007), so
    # they instead name their guarantor by member number, which the view
    # resolves itself. Exactly one of the two must be supplied.
    guarantor = serializers.PrimaryKeyRelatedField(queryset=Member.objects.all(), required=False)
    guarantor_member_number = serializers.CharField(required=False, allow_blank=True)
    pledged_amount = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0.01"))

    def validate(self, attrs):
        guarantor = attrs.get("guarantor")
        member_number = attrs.get("guarantor_member_number")
        if not guarantor and not member_number:
            raise serializers.ValidationError("Provide either guarantor or guarantor_member_number.")
        if not guarantor:
            try:
                attrs["guarantor"] = Member.objects.get(member_number=member_number)
            except Member.DoesNotExist:
                raise serializers.ValidationError({"guarantor_member_number": "No member with that number."})
        attrs.pop("guarantor_member_number", None)
        return attrs


class RespondGuaranteeInputSerializer(serializers.Serializer):
    accept = serializers.BooleanField()


class AppraiseInputSerializer(serializers.Serializer):
    notes = serializers.CharField(required=False, allow_blank=True, default="")


class DecideInputSerializer(serializers.Serializer):
    approved = serializers.BooleanField()
    notes = serializers.CharField(required=False, allow_blank=True, default="")


class DisburseToSavingsInputSerializer(serializers.Serializer):
    product = serializers.PrimaryKeyRelatedField(queryset=SavingsProduct.objects.filter(is_active=True))


class DisburseMobileMoneyInputSerializer(serializers.Serializer):
    phone_number = serializers.CharField()
    idempotency_key = serializers.CharField(required=False, allow_blank=True, max_length=64)


class RecordRepaymentInputSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0.01"))
    transaction_date = serializers.DateField()
    description = serializers.CharField(required=False, allow_blank=True, default="")


class MarkDefaultedInputSerializer(serializers.Serializer):
    notes = serializers.CharField(required=False, allow_blank=True, default="")
