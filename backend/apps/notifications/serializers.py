from __future__ import annotations

from rest_framework import serializers

from .models import Notification, NotificationToken


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = (
            "id",
            "title",
            "body",
            "notification_type",
            "is_read",
            "sent_at",
            "related_object_id",
            "created_at",
        )
        read_only_fields = fields


class NotificationTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationToken
        fields = ("id", "device_token", "platform", "is_active")
        read_only_fields = ("id",)


class NotificationBroadcastSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=255)
    body = serializers.CharField()
    send_to_all = serializers.BooleanField(default=False)
    specialty_id = serializers.UUIDField(required=False, allow_null=True)
