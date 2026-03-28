from django.contrib import admin

from .models import ChatRoom, Message, PatientAIMessage


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
    list_display = ("patient", "role", "created_at")
    list_filter = ("tenant", "role")
    search_fields = ("patient__email", "patient__first_name", "patient__last_name", "content")
