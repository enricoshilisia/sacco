from rest_framework import serializers

from .models import AuditEvent


class AuditEventSerializer(serializers.ModelSerializer):
    action_label = serializers.CharField(source="get_action_display", read_only=True)

    class Meta:
        model = AuditEvent
        fields = [
            "id", "at", "user", "actor", "action", "action_label", "event", "area", "summary",
            "method", "path", "status_code", "target_type", "target_id", "target_label",
            "ip_address", "location", "latitude", "longitude", "device", "user_agent", "duration_ms",
        ]
        read_only_fields = fields
