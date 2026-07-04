from decimal import Decimal

from rest_framework import serializers

from savings.models import SavingsProduct

from .models import CollectionPurpose, PaymentCollection


class PaymentCollectionSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source="member.full_name", read_only=True)
    product_name = serializers.SerializerMethodField()

    class Meta:
        model = PaymentCollection
        fields = [
            "id", "member", "member_name", "purpose", "savings_account", "product_name",
            "provider", "phone_number", "amount", "status",
            "provider_reference", "provider_receipt", "failure_reason",
            "created_at", "completed_at",
        ]

    def get_product_name(self, collection):
        # Only meaningful for a savings-deposit collection - a share
        # contribution has no per-product account (CLAUDE.md: share
        # capital != deposits).
        return collection.savings_account.product.name if collection.savings_account else None


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


class MyInitiateCollectionInputSerializer(serializers.Serializer):
    """Self-service: a member funding their own account via mobile money -
    either a savings deposit (needs a product) or a share contribution
    (doesn't). Mirrors InitiateCollectionInputSerializer, minus the
    member_id (resolved from request.user, not a URL parameter - the same
    ownership-scoped shape every other self-service endpoint uses)."""

    purpose = serializers.ChoiceField(choices=CollectionPurpose.choices, default=CollectionPurpose.SAVINGS_DEPOSIT)
    product = serializers.PrimaryKeyRelatedField(
        queryset=SavingsProduct.objects.filter(is_active=True), required=False
    )
    amount = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0.01"))
    phone_number = serializers.CharField()
    idempotency_key = serializers.CharField(required=False, allow_blank=True, max_length=64)

    def validate(self, attrs):
        if attrs.get("purpose", CollectionPurpose.SAVINGS_DEPOSIT) == CollectionPurpose.SAVINGS_DEPOSIT and not attrs.get(
            "product"
        ):
            raise serializers.ValidationError({"product": "Required for a savings deposit."})
        return attrs
