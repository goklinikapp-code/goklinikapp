from django.contrib import admin

from .models import Notification, NotificationToken


@admin.register(NotificationToken)
class NotificationTokenAdmin(admin.ModelAdmin):
    list_display = ("user", "platform", "is_active", "created_at")
    list_filter = ("platform", "is_active")


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("recipient", "notification_type", "is_read", "sent_at", "created_at")
    list_filter = ("notification_type", "is_read", "tenant")
    search_fields = ("recipient__email", "title", "body")
