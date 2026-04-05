from django.contrib import admin

from .models import (
    Notification,
    NotificationLog,
    NotificationTemplate,
    NotificationToken,
    NotificationWorkflow,
    ScheduledNotification,
)


@admin.register(NotificationToken)
class NotificationTokenAdmin(admin.ModelAdmin):
    list_display = ("user", "platform", "is_active", "created_at")
    list_filter = ("platform", "is_active")


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("recipient", "notification_type", "is_read", "sent_at", "created_at")
    list_filter = ("notification_type", "is_read", "tenant")
    search_fields = ("recipient__email", "title", "body")


@admin.register(NotificationTemplate)
class NotificationTemplateAdmin(admin.ModelAdmin):
    list_display = ("code", "tenant", "is_active", "created_by", "created_at", "updated_at")
    list_filter = ("is_active", "tenant")
    search_fields = ("code", "title_template", "body_template", "tenant__name")


@admin.register(NotificationLog)
class NotificationLogAdmin(admin.ModelAdmin):
    list_display = ("user", "channel", "status", "event_code", "segment", "created_at")
    list_filter = ("channel", "status", "event_code", "segment")
    search_fields = ("user__email", "title", "body", "error_message", "idempotency_key")


@admin.register(NotificationWorkflow)
class NotificationWorkflowAdmin(admin.ModelAdmin):
    list_display = ("name", "tenant", "trigger_type", "trigger_offset", "is_active", "created_at")
    list_filter = ("trigger_type", "is_active", "tenant")
    search_fields = ("name", "tenant__name")


@admin.register(ScheduledNotification)
class ScheduledNotificationAdmin(admin.ModelAdmin):
    list_display = ("tenant", "segment", "run_at", "status", "created_by", "created_at")
    list_filter = ("status", "segment", "tenant")
    search_fields = ("tenant__name", "title", "body", "error_message")
