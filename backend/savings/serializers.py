from decimal import Decimal

from rest_framework import serializers

from accounting.models import Account

from .models import (
    SavingsAccount,
    SavingsProduct,
    SavingsTransaction,
    ShareAccount,
    ShareContribution,
)
from .services import SAVINGS_CONTROL_ACCOUNT_CODE, SHARE_CAPITAL_ACCOUNT_CODE


class SavingsProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = SavingsProduct
        fields = ["id", "name", "code", "product_type", "interest_rate", "minimum_balance", "is_active"]


class ShareAccountSerializer(serializers.ModelSerializer):
    balance = serializers.SerializerMethodField()

    class Meta:
        model = ShareAccount
        fields = ["id", "member", "opened_at", "balance"]

    def get_balance(self, obj) -> str:
        account = Account.objects.get(code=SHARE_CAPITAL_ACCOUNT_CODE)
        return str(account.balance(member=obj.member))


class SavingsAccountSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name", read_only=True)
    product_type = serializers.CharField(source="product.product_type", read_only=True)
    balance = serializers.SerializerMethodField()

    class Meta:
        model = SavingsAccount
        fields = [
            "id", "member", "product", "product_name", "product_type",
            "account_number", "opened_at", "is_active", "balance",
        ]

    def get_balance(self, obj) -> str:
        account = Account.objects.get(code=SAVINGS_CONTROL_ACCOUNT_CODE)
        return str(account.balance(member=obj.member))


class ShareContributionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ShareContribution
        fields = ["id", "amount", "transaction_date", "created_at", "created_by"]


class SavingsTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = SavingsTransaction
        fields = ["id", "transaction_type", "amount", "transaction_date", "created_at", "created_by"]


class ContributeSharesInputSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0.01"))
    transaction_date = serializers.DateField()
    description = serializers.CharField(required=False, allow_blank=True, default="")


class DepositInputSerializer(serializers.Serializer):
    product = serializers.PrimaryKeyRelatedField(queryset=SavingsProduct.objects.filter(is_active=True))
    amount = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0.01"))
    transaction_date = serializers.DateField()
    description = serializers.CharField(required=False, allow_blank=True, default="")


class WithdrawInputSerializer(serializers.Serializer):
    savings_account = serializers.PrimaryKeyRelatedField(queryset=SavingsAccount.objects.all())
    amount = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0.01"))
    transaction_date = serializers.DateField()
    description = serializers.CharField(required=False, allow_blank=True, default="")
