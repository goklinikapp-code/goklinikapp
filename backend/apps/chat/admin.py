from django.contrib import admin

from .models import (
    ChatRoom,
    Message,
    PatientAIConversationControl,
    PatientAIMessage,
    PatientAITypingStatus,
    TenantAIChatSettings,
)


@admin.register(ChatRoom)
class ChatRoomAdmin(admin.ModelAdmin):
    list_display = ("room_type", "patient", "staff_member", "last_message_at")
    list_filter = ("tenant", "room_type")


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ("room", "sender", "message_type", "is_read", "created_at")
    list_filter = ("message_type", "is_read")


@admin.register(PatientAIMessage)
class PatientAIMessageAdmin(admin.ModelAdmin):
    list_display = ("patient", "role", "source", "sender_user", "created_at")
    list_filter = ("tenant", "role", "source")
    search_fields = ("patient__email", "patient__first_name", "patient__last_name", "content")


@admin.register(TenantAIChatSettings)
class TenantAIChatSettingsAdmin(admin.ModelAdmin):
    list_display = ("tenant", "ai_enabled", "updated_by", "updated_at")
    list_filter = ("ai_enabled",)
    search_fields = ("tenant__name", "tenant__slug")


@admin.register(PatientAIConversationControl)
class PatientAIConversationControlAdmin(admin.ModelAdmin):
    list_display = ("patient", "tenant", "force_human", "updated_by", "updated_at")
    list_filter = ("force_human", "tenant")
    search_fields = ("patient__email", "patient__first_name", "patient__last_name")


@admin.register(PatientAITypingStatus)
class PatientAITypingStatusAdmin(admin.ModelAdmin):
    list_display = ("patient", "tenant", "is_typing", "typed_by", "expires_at", "updated_at")
    list_filter = ("is_typing", "tenant")
    search_fields = ("patient__email", "patient__first_name", "patient__last_name")
