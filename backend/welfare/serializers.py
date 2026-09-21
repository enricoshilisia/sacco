from decimal import Decimal

from rest_framework import serializers

from members.models import Member

from .models import (
    WelfareCase,
    WelfareCaseType,
    WelfareContribution,
    WelfarePayment,
    WelfarePaymentMethod,
    WelfarePayout,
    WelfareSettings,
    WelfareYearClose,
)
from .services import case_collected, case_paid_out

MONEY = {"max_digits": 18, "decimal_places": 2}


class WelfareSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = WelfareSettings
        fields = ["yearly_contribution", "updated_at"]
        read_only_fields = ["updated_at"]

    def validate_yearly_contribution(self, value):
        if value < 0:
            raise serializers.ValidationError("Must not be negative.")
        return value


class WelfareCaseTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = WelfareCaseType
        fields = ["id", "name", "description", "contribution_per_member", "beneficiary_contributes", "is_active"]

    def validate_contribution_per_member(self, value):
        if value <= 0:
            raise serializers.ValidationError("Must be greater than zero.")
        return value


class MemberBriefSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(read_only=True)

    class Meta:
        model = Member
        fields = ["id", "member_number", "full_name", "phone_number", "status"]


class WelfarePayoutSerializer(serializers.ModelSerializer):
    recorded_by_name = serializers.CharField(source="recorded_by.get_full_name", read_only=True, default=None)

    class Meta:
        model = WelfarePayout
        fields = ["id", "amount", "method", "reference", "paid_to", "paid_on", "notes", "recorded_by_name", "created_at"]


class WelfareCaseSerializer(serializers.ModelSerializer):
    case_type_name = serializers.CharField(source="case_type.name", read_only=True)
    beneficiary = MemberBriefSerializer(read_only=True)
    created_by_name = serializers.CharField(source="created_by.get_full_name", read_only=True, default=None)
    decided_by_name = serializers.CharField(source="decided_by.get_full_name", read_only=True, default=None)
    members_levied = serializers.SerializerMethodField()
    total_levied = serializers.SerializerMethodField()
    collected = serializers.SerializerMethodField()
    outstanding = serializers.SerializerMethodField()
    paid_out = serializers.SerializerMethodField()
    available_to_pay = serializers.SerializerMethodField()
    payouts = WelfarePayoutSerializer(many=True, read_only=True)

    class Meta:
        model = WelfareCase
        fields = [
            "id", "case_type", "case_type_name", "beneficiary", "affected_person", "description",
            "contribution_per_member", "beneficiary_contributes", "status",
            "created_by_name", "created_at", "decided_by_name", "decided_at", "decision_notes",
            "levied_at", "closed_at",
            "members_levied", "total_levied", "collected", "outstanding", "paid_out", "available_to_pay", "payouts",
        ]

    # Money as strings, like every balance in the API (CLAUDE.md rule 1).
    def _totals(self, case):
        if not hasattr(case, "_welfare_totals"):
            collected = case_collected(case)
            paid_out = case_paid_out(case)
            contributions = case.contributions.all()
            total_levied = sum((c.amount for c in contributions), Decimal("0"))
            case._welfare_totals = {
                "members_levied": len(contributions),
                "total_levied": total_levied,
                "collected": collected,
                "outstanding": total_levied - collected,
                "paid_out": paid_out,
                "available_to_pay": collected - paid_out,
            }
        return case._welfare_totals

    def get_members_levied(self, case):
        return self._totals(case)["members_levied"]

    def get_total_levied(self, case):
        return str(self._totals(case)["total_levied"])

    def get_collected(self, case):
        return str(self._totals(case)["collected"])

    def get_outstanding(self, case):
        return str(self._totals(case)["outstanding"])

    def get_paid_out(self, case):
        return str(self._totals(case)["paid_out"])

    def get_available_to_pay(self, case):
        return str(self._totals(case)["available_to_pay"])


class CreateCaseInputSerializer(serializers.Serializer):
    case_type = serializers.PrimaryKeyRelatedField(queryset=WelfareCaseType.objects.filter(is_active=True))
    beneficiary = serializers.PrimaryKeyRelatedField(queryset=Member.objects.all())
    affected_person = serializers.CharField(required=False, allow_blank=True, default="", max_length=255)
    description = serializers.CharField(required=False, allow_blank=True, default="")


class DecisionInputSerializer(serializers.Serializer):
    notes = serializers.CharField(required=False, allow_blank=True, default="")


class RejectInputSerializer(serializers.Serializer):
    notes = serializers.CharField()


class RecordPayoutInputSerializer(serializers.Serializer):
    amount = serializers.DecimalField(**MONEY, min_value=Decimal("0.01"))
    method = serializers.ChoiceField(choices=[WelfarePaymentMethod.CASH, WelfarePaymentMethod.BANK,
                                              WelfarePaymentMethod.MOBILE_MONEY])
    paid_on = serializers.DateField()
    reference = serializers.CharField(required=False, allow_blank=True, default="", max_length=100)
    paid_to = serializers.CharField(required=False, allow_blank=True, default="", max_length=255)
    notes = serializers.CharField(required=False, allow_blank=True, default="")


class RecordPaymentInputSerializer(serializers.Serializer):
    amount = serializers.DecimalField(**MONEY, min_value=Decimal("0.01"))
    method = serializers.ChoiceField(choices=[WelfarePaymentMethod.CASH, WelfarePaymentMethod.BANK])
    transaction_date = serializers.DateField()
    reference = serializers.CharField(required=False, allow_blank=True, default="", max_length=100)


class WelfareContributionSerializer(serializers.ModelSerializer):
    case_type_name = serializers.CharField(source="case.case_type.name", read_only=True)
    beneficiary_name = serializers.CharField(source="case.beneficiary.full_name", read_only=True)
    affected_person = serializers.CharField(source="case.affected_person", read_only=True)
    member_number = serializers.CharField(source="member.member_number", read_only=True)
    member_name = serializers.CharField(source="member.full_name", read_only=True)
    outstanding = serializers.SerializerMethodField()

    class Meta:
        model = WelfareContribution
        fields = [
            "id", "case", "case_type_name", "beneficiary_name", "affected_person", "member", "member_number",
            "member_name", "amount", "from_balance", "owed", "paid", "outstanding", "created_at",
        ]

    def get_outstanding(self, contribution):
        return str(contribution.outstanding)


class WelfarePaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = WelfarePayment
        fields = ["id", "amount", "applied_to_dues", "to_balance", "method", "reference", "transaction_date", "created_at"]


class WelfareYearCloseSerializer(serializers.ModelSerializer):
    members_swept = serializers.SerializerMethodField()
    total_swept = serializers.SerializerMethodField()

    class Meta:
        model = WelfareYearClose
        fields = ["id", "year", "status", "started_at", "finished_at", "members_swept", "total_swept"]

    def get_members_swept(self, obj):
        return obj.sweeps.count()

    def get_total_swept(self, obj):
        return str(sum((s.amount for s in obj.sweeps.all()), Decimal("0")))


def summary_payload(summary: dict) -> dict:
    return {
        "balance": str(summary["balance"]),
        "owed": str(summary["owed"]),
        "yearly_contribution": str(summary["yearly_contribution"]),
        "paid_this_year": str(summary["paid_this_year"]),
        "year": summary["year"],
    }
