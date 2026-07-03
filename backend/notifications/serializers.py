from rest_framework import serializers

from .models import NotificationLog


class NotificationLogSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source="member.full_name", read_only=True, default=None)

    class Meta:
        model = NotificationLog
        fields = [
            "id", "member", "member_name", "channel", "event_type", "recipient",
            "message", "provider", "status", "provider_message_id", "error",
            "created_at", "sent_at",
        ]
