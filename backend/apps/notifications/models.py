from __future__ import annotations

import uuid

from django.db import models


class NotificationToken(models.Model):
    class PlatformChoices(models.TextChoices):
        IOS = "ios", "iOS"
        ANDROID = "android", "Android"
        WEB = "web", "Web"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.CASCADE,
        related_name="notification_tokens",
    )
    device_token = models.TextField()
    platform = models.CharField(max_length=20, choices=PlatformChoices.choices)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "notification_tokens"
        unique_together = ("user", "device_token")

    def __str__(self):
        return f"{self.user.email} - {self.platform}"


class Notification(models.Model):
    class NotificationTypeChoices(models.TextChoices):
        APPOINTMENT_REMINDER = "appointment_reminder", "Appointment Reminder"
        POSTOP_ALERT = "postop_alert", "Post-op Alert"
        NEW_MESSAGE = "new_message", "New Message"
        PROMOTION = "promotion", "Promotion"
        SYSTEM = "system", "System"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    recipient = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    title = models.CharField(max_length=255)
    body = models.TextField()
    notification_type = models.CharField(max_length=30, choices=NotificationTypeChoices.choices)
    related_object_id = models.UUIDField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    sent_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "notifications"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.recipient.email}: {self.title}"
