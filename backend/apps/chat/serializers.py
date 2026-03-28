from __future__ import annotations

from rest_framework import serializers

from apps.patients.models import Patient
from apps.users.models import GoKlinikUser

from .models import ChatRoom, Message, PatientAIMessage


class ChatRoomCreateSerializer(serializers.Serializer):
    patient_id = serializers.UUIDField()
    room_type = serializers.ChoiceField(choices=ChatRoom.RoomTypeChoices.choices)

    def validate_patient_id(self, value):
        patient = Patient.objects.filter(id=value).first()
        if not patient:
            raise serializers.ValidationError("Patient not found.")
        return value


class ChatMessageCreateSerializer(serializers.Serializer):
    content = serializers.CharField()
    message_type = serializers.ChoiceField(choices=(Message.MessageTypeChoices.TEXT, Message.MessageTypeChoices.IMAGE))


class MessageSerializer(serializers.ModelSerializer):
    sender = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ("id", "sender", "content", "message_type", "is_read", "created_at")

    def get_sender(self, obj):
        return {
            "id": str(obj.sender_id),
            "name": obj.sender.full_name,
            "avatar": obj.sender.avatar_url,
        }


class ChatRoomListSerializer(serializers.ModelSerializer):
    interlocutor_name = serializers.SerializerMethodField()
    interlocutor_avatar = serializers.SerializerMethodField()
    last_message_preview = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = ChatRoom
        fields = (
            "id",
            "room_type",
            "interlocutor_name",
            "interlocutor_avatar",
            "last_message_preview",
            "last_message_at",
            "unread_count",
        )

    def _interlocutor(self, obj):
        user = self.context["request"].user
        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            return obj.staff_member
        return obj.patient

    def get_interlocutor_name(self, obj):
        interlocutor = self._interlocutor(obj)
        if interlocutor:
            return interlocutor.full_name
        if obj.room_type == ChatRoom.RoomTypeChoices.DOCTOR_PATIENT:
            return "Equipe da clínica"
        return "Clínica"

    def get_interlocutor_avatar(self, obj):
        interlocutor = self._interlocutor(obj)
        if not interlocutor:
            return ""
        return interlocutor.avatar_url or ""

    def get_last_message_preview(self, obj):
        if not hasattr(obj, "_last_message"):
            obj._last_message = obj.messages.order_by("-created_at").first()  # type: ignore[attr-defined]
        if not obj._last_message:  # type: ignore[attr-defined]
            return ""
        preview = obj._last_message.content.strip()  # type: ignore[attr-defined]
        return preview[:60]

    def get_unread_count(self, obj):
        user = self.context["request"].user
        return obj.messages.exclude(sender_id=user.id).filter(is_read=False).count()


class PatientAIMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = PatientAIMessage
        fields = ("id", "role", "content", "created_at")
        read_only_fields = fields


class PatientAIMessageCreateSerializer(serializers.Serializer):
    content = serializers.CharField(min_length=1, max_length=4000)
