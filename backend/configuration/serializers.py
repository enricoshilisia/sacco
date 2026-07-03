from rest_framework import serializers

from .models import IdType, TenantConfig


class TenantConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = TenantConfig
        fields = [
            "default_language",
            "allowed_id_types",
            "member_number_prefix",
            "member_number_suffix",
            "member_number_padding",
            "member_number_next_sequence",
            "active_sms_provider",
            "active_payment_provider",
        ]
        read_only_fields = ["member_number_next_sequence"]

    def validate_allowed_id_types(self, value):
        valid = set(IdType.values)
        invalid = set(value) - valid
        if invalid:
            raise serializers.ValidationError(f"Unknown ID type(s): {', '.join(sorted(invalid))}")
        return value

    def validate_active_sms_provider(self, value):
        from notifications.providers.registry import SMS_PROVIDERS

        if value and value not in SMS_PROVIDERS:
            raise serializers.ValidationError(f"Unknown SMS provider '{value}'.")
        return value

    def validate_active_payment_provider(self, value):
        from payments.providers.registry import PAYMENT_PROVIDERS

        if value and value not in PAYMENT_PROVIDERS:
            raise serializers.ValidationError(f"Unknown payment provider '{value}'.")
        return value

    def validate_member_number_prefix(self, value):
        if len(value) > 20:
            raise serializers.ValidationError("Prefix must be 20 characters or fewer.")
        return value

    def validate_member_number_suffix(self, value):
        if len(value) > 20:
            raise serializers.ValidationError("Suffix must be 20 characters or fewer.")
        return value
