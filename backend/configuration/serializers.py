from rest_framework import serializers

from .models import IdType, TenantConfig


class TenantConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = TenantConfig
        fields = [
            "default_language",
            "allowed_id_types",
            "member_number_prefix",
            "member_number_padding",
            "member_number_next_sequence",
        ]
        read_only_fields = ["member_number_next_sequence"]

    def validate_allowed_id_types(self, value):
        valid = set(IdType.values)
        invalid = set(value) - valid
        if invalid:
            raise serializers.ValidationError(f"Unknown ID type(s): {', '.join(sorted(invalid))}")
        return value

    def validate_member_number_prefix(self, value):
        if len(value) > 20:
            raise serializers.ValidationError("Prefix must be 20 characters or fewer.")
        return value
