from decimal import Decimal

from rest_framework import serializers

from savings.models import SavingsProduct

from .models import PaymentCollection


class PaymentCollectionSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source="member.full_name", read_only=True)
    product_name = serializers.CharField(source="savings_account.product.name", read_only=True)

    class Meta:
        model = PaymentCollection
        fields = [
            "id", "member", "member_name", "savings_account", "product_name",
            "provider", "phone_number", "amount", "status",
            "provider_reference", "provider_receipt", "failure_reason",
            "created_at", "completed_at",
        ]


class InitiateCollectionInputSerializer(serializers.Serializer):
    product = serializers.PrimaryKeyRelatedField(queryset=SavingsProduct.objects.filter(is_active=True))
    amount = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0.01"))
    phone_number = serializers.CharField(required=False, allow_blank=True)
    # Optional: a caller that needs retry-safety across its own network
    # failures (e.g. a mobile client retrying a timed-out request) should
    # generate and reuse its own key here - CLAUDE.md rule 4. Without one,
    # a fresh key is generated per call, which only protects against the
    # PROVIDER redelivering a callback, not the client double-submitting.
    idempotency_key = serializers.CharField(required=False, allow_blank=True, max_length=64)
