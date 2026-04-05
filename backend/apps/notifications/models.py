from __future__ import annotations

import uuid

from django.db import models
from django.db.models import Q


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


class NotificationTemplate(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="notification_templates",
        null=True,
        blank=True,
    )
    created_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_notification_templates",
    )
    code = models.CharField(max_length=60)
    title_template = models.CharField(max_length=255)
    body_template = models.TextField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "notification_templates"
        ordering = ["code"]
        constraints = [
            models.UniqueConstraint(
                fields=["tenant", "code"],
                name="notification_template_unique_code_per_tenant",
            ),
        ]
        indexes = [
            models.Index(fields=["tenant", "is_active", "code"]),
        ]

    def __str__(self):
        return f"{self.tenant_id or 'system'}:{self.code}"


class NotificationLog(models.Model):
    class ChannelChoices(models.TextChoices):
        PUSH = "push", "Push"

    class StatusChoices(models.TextChoices):
        SENT = "sent", "Sent"
        ERROR = "error", "Error"
        SKIPPED = "skipped", "Skipped"
        RATE_LIMITED = "rate_limited", "Rate limited"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="notification_logs",
        null=True,
        blank=True,
    )
    user = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.CASCADE,
        related_name="notification_logs",
    )
    title = models.CharField(max_length=255)
    body = models.TextField()
    channel = models.CharField(
        max_length=20,
        choices=ChannelChoices.choices,
        default=ChannelChoices.PUSH,
    )
    status = models.CharField(max_length=20, choices=StatusChoices.choices)
    event_code = models.CharField(max_length=80, blank=True)
    segment = models.CharField(max_length=80, blank=True)
    idempotency_key = models.CharField(max_length=255, null=True, blank=True)
    data_extra = models.JSONField(default=dict, blank=True)
    error_message = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "notification_logs"
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "idempotency_key"],
                condition=Q(idempotency_key__isnull=False),
                name="notification_log_unique_idempotency_per_user",
            )
        ]
        indexes = [
            models.Index(fields=["tenant", "created_at"]),
            models.Index(fields=["user", "status", "created_at"]),
            models.Index(fields=["event_code", "created_at"]),
        ]

    def __str__(self):
        return f"{self.user_id}:{self.status}:{self.channel}"


class NotificationWorkflow(models.Model):
    class TriggerTypeChoices(models.TextChoices):
        APPOINTMENT_CREATED = "appointment_created", "Appointment Created"
        REMINDER_BEFORE = "reminder_before", "Reminder Before Appointment"
        POST_OP_FOLLOWUP = "post_op_followup", "Post-op Follow-up"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="notification_workflows",
    )
    name = models.CharField(max_length=120)
    is_active = models.BooleanField(default=True)
    trigger_type = models.CharField(max_length=32, choices=TriggerTypeChoices.choices)
    trigger_offset = models.CharField(
        max_length=16,
        blank=True,
        default="",
        help_text="Offset format: 24h, 7d, 30m.",
    )
    template = models.ForeignKey(
        "notifications.NotificationTemplate",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="workflows",
    )
    created_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_notification_workflows",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "notification_workflows"
        ordering = ["name"]
        indexes = [
            models.Index(fields=["tenant", "is_active", "trigger_type"]),
            models.Index(fields=["tenant", "trigger_type"]),
        ]

    def __str__(self) -> str:
        return f"{self.tenant_id}:{self.name}:{self.trigger_type}"


class ScheduledNotification(models.Model):
    class StatusChoices(models.TextChoices):
        PENDING = "pending", "Pending"
        RUNNING = "running", "Running"
        COMPLETED = "completed", "Completed"
        ERROR = "error", "Error"
        CANCELED = "canceled", "Canceled"

    class SegmentChoices(models.TextChoices):
        ALL_PATIENTS = "all_patients", "All patients"
        FUTURE_APPOINTMENTS = "future_appointments", "Future appointments"
        INACTIVE_PATIENTS = "inactive_patients", "Inactive patients"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="scheduled_notifications",
    )
    created_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="scheduled_notifications",
    )
    run_at = models.DateTimeField()
    segment = models.CharField(max_length=40, choices=SegmentChoices.choices)
    title = models.CharField(max_length=255, blank=True)
    body = models.TextField(blank=True)
    template = models.ForeignKey(
        "notifications.NotificationTemplate",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="scheduled_notifications",
    )
    template_context = models.JSONField(default=dict, blank=True)
    data_extra = models.JSONField(default=dict, blank=True)
    status = models.CharField(
        max_length=20,
        choices=StatusChoices.choices,
        default=StatusChoices.PENDING,
    )
    celery_task_id = models.CharField(max_length=64, blank=True)
    summary = models.JSONField(default=dict, blank=True)
    error_message = models.TextField(blank=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "scheduled_notifications"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["tenant", "status", "run_at"]),
            models.Index(fields=["run_at", "status"]),
        ]

    def __str__(self) -> str:
        return f"{self.tenant_id}:{self.segment}:{self.run_at}"
