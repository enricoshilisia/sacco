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

    class Meta:
        model = JournalEntry
        fields = [
            "id", "reference", "description", "entry_date",
            "reverses", "reverses_reference", "created_at", "lines",
        ]
