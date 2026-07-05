from decimal import Decimal

from rest_framework import serializers

from savings.models import SavingsProduct

from .models import DistributionEntry, DistributionRun


class DistributionEntrySerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source="member.full_name", read_only=True)
    member_number = serializers.CharField(source="member.member_number", read_only=True)
    latest_payout = serializers.SerializerMethodField()

    class Meta:
        model = DistributionEntry
        fields = [
            "id", "run", "member", "member_name", "member_number", "savings_account",
            "basis_balance", "gross_amount", "wht_amount", "net_amount", "status", "latest_payout",
        ]

    def get_latest_payout(self, entry):
        payout = entry.payouts.order_by("-created_at").first()
        if payout is None:
            return None
        return {
            "id": str(payout.id),
            "provider": payout.provider,
            "status": payout.status,
            "provider_reference": payout.provider_reference,
            "phone_number": payout.phone_number,
            "amount": str(payout.amount),
            "failure_reason": payout.failure_reason,
        }


class DistributionRunSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="savings_product.name", read_only=True, default=None)
    entries = DistributionEntrySerializer(many=True, read_only=True)
    total_gross = serializers.SerializerMethodField()
    total_wht = serializers.SerializerMethodField()
    total_net = serializers.SerializerMethodField()
    member_count = serializers.SerializerMethodField()
    proposed_by_name = serializers.CharField(source="proposed_by.get_full_name", read_only=True, default=None)
    approved_by_name = serializers.CharField(source="approved_by.get_full_name", read_only=True, default=None)
    rejected_by_name = serializers.CharField(source="rejected_by.get_full_name", read_only=True, default=None)

    class Meta:
        model = DistributionRun
        fields = [
            "id", "kind", "savings_product", "product_name", "period_start", "period_end",
            "rate", "wht_rate", "wht_rates_confirmed_by_tax_adviser", "status", "description",
            "proposed_by_name", "proposed_at", "approved_by_name", "approved_at",
            "rejected_by_name", "rejected_at", "rejection_reason",
            "entries", "total_gross", "total_wht", "total_net", "member_count",
        ]

    def get_total_gross(self, run):
        return sum((e.gross_amount for e in run.entries.all()), Decimal("0"))

    def get_total_wht(self, run):
        return sum((e.wht_amount for e in run.entries.all()), Decimal("0"))

    def get_total_net(self, run):
        return sum((e.net_amount for e in run.entries.all()), Decimal("0"))

    def get_member_count(self, run):
        return run.entries.count()


class DistributionRunListSerializer(serializers.ModelSerializer):
    """Lighter-weight shape for the run list (no nested entries)."""

    product_name = serializers.CharField(source="savings_product.name", read_only=True, default=None)
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = DistributionRun
        fields = [
            "id", "kind", "savings_product", "product_name", "period_start", "period_end",
            "rate", "status", "description", "proposed_at", "member_count",
        ]

    def get_member_count(self, run):
        return run.entries.count()


class ProposeDividendRunInputSerializer(serializers.Serializer):
    period_start = serializers.DateField()
    period_end = serializers.DateField()
    rate = serializers.DecimalField(max_digits=6, decimal_places=4, min_value=Decimal("0.0001"))
    description = serializers.CharField(required=False, allow_blank=True, default="")


class ProposeInterestRunInputSerializer(serializers.Serializer):
    savings_product = serializers.PrimaryKeyRelatedField(queryset=SavingsProduct.objects.filter(is_active=True))
    period_start = serializers.DateField()
    period_end = serializers.DateField()
    rate = serializers.DecimalField(
        max_digits=6, decimal_places=4, min_value=Decimal("0.0001"), required=False, allow_null=True, default=None
    )
    description = serializers.CharField(required=False, allow_blank=True, default="")


class RejectRunInputSerializer(serializers.Serializer):
    reason = serializers.CharField()


class InitiatePayoutInputSerializer(serializers.Serializer):
    phone_number = serializers.CharField(required=False, allow_blank=True, default="")
    idempotency_key = serializers.CharField(required=False, allow_blank=True, max_length=64, default="")
