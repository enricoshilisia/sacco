from decimal import Decimal

from rest_framework import serializers

from .models import Account, JournalEntry, JournalLine


class AccountBalanceSerializer(serializers.ModelSerializer):
    balance = serializers.SerializerMethodField()

    class Meta:
        model = Account
        fields = ["id", "code", "name", "account_type", "is_control_account", "balance"]

    def get_balance(self, account) -> str:
        return str(account.balance())


class JournalLineSerializer(serializers.ModelSerializer):
    account_code = serializers.CharField(source="account.code", read_only=True)
    account_name = serializers.CharField(source="account.name", read_only=True)
    member_name = serializers.CharField(source="member.full_name", read_only=True, default=None)

    class Meta:
        model = JournalLine
        fields = [
            "id", "account", "account_code", "account_name",
            "debit", "credit", "member", "member_name", "description",
        ]


class JournalEntrySerializer(serializers.ModelSerializer):
    lines = JournalLineSerializer(many=True, read_only=True)
    reverses_reference = serializers.CharField(source="reverses.reference", read_only=True, default=None)
    reversed_by_reference = serializers.SerializerMethodField()
    created_by_name = serializers.CharField(source="created_by.get_full_name", read_only=True, default=None)

    class Meta:
        model = JournalEntry
        fields = [
            "id", "reference", "description", "entry_date",
            "reverses", "reverses_reference", "reversed_by_reference", "created_by_name", "created_at", "lines",
        ]

    def get_reversed_by_reference(self, entry):
        reversal = getattr(entry, "reversed_by", None)
        return reversal.reference if reversal else None


class AccountSerializer(serializers.ModelSerializer):
    class Meta:
        model = Account
        fields = ["id", "code", "name", "account_type", "is_control_account", "is_active"]
        read_only_fields = ["id", "is_control_account"]


class ManualLineInputSerializer(serializers.Serializer):
    account = serializers.PrimaryKeyRelatedField(queryset=Account.objects.filter(is_active=True))
    debit = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0"), default=Decimal("0"))
    credit = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0"), default=Decimal("0"))
    description = serializers.CharField(required=False, allow_blank=True, default="", max_length=255)


class ManualJournalInputSerializer(serializers.Serializer):
    description = serializers.CharField(max_length=255)
    entry_date = serializers.DateField()
    lines = ManualLineInputSerializer(many=True)

    def validate_lines(self, lines):
        # Member sub-ledgers (savings, shares, loans, welfare) only move
        # through their own modules, so every member's balance keeps
        # reconciling to its control account. Manual journals are for
        # everything else: expenses, fees, bank charges, adjustments.
        control = [line["account"].code for line in lines if line["account"].is_control_account]
        if control:
            raise serializers.ValidationError(
                f"Member control accounts ({', '.join(control)}) can't be used in a manual journal; "
                "use the savings, loans or welfare screens, or reverse the original entry."
            )
        return lines
