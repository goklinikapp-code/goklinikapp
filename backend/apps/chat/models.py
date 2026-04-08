from __future__ import annotations

import uuid

from django.db import models


class ChatRoom(models.Model):
    class RoomTypeChoices(models.TextChoices):
        NURSING_POSTOP = "nursing_postop", "Nursing Post-op"
        DOCTOR_PATIENT = "doctor_patient", "Doctor Patient"
        SECRETARY_SCHEDULING = "secretary_scheduling", "Secretary Scheduling"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="chat_rooms",
    )
    room_type = models.CharField(max_length=30, choices=RoomTypeChoices.choices)
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="chat_rooms",
    )
    staff_member = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.CASCADE,
        related_name="staff_chat_rooms",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    last_message_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "chat_rooms"
        ordering = ["-last_message_at", "-created_at"]

    def __str__(self) -> str:
        return f"{self.room_type} - {self.patient.full_name}"


class Message(models.Model):
    class MessageTypeChoices(models.TextChoices):
        TEXT = "text", "Text"
        IMAGE = "image", "Image"
        QUICK_REPLY = "quick_reply", "Quick Reply"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    room = models.ForeignKey(ChatRoom, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.CASCADE,
        related_name="sent_messages",
    )
    content = models.TextField()
    message_type = models.CharField(
        max_length=20,
        choices=MessageTypeChoices.choices,
        default=MessageTypeChoices.TEXT,
    )
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "chat_messages"
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"{self.sender.full_name}: {self.content[:30]}"


class TenantAIChatSettings(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.OneToOneField(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="ai_chat_settings",
    )
    ai_enabled = models.BooleanField(default=True)
    updated_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ai_chat_settings_updates",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "chat_ai_settings"

    def __str__(self) -> str:
        return f"{self.tenant_id}:{'enabled' if self.ai_enabled else 'paused'}"


class PatientAIConversationControl(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="patient_ai_controls",
    )
    patient = models.OneToOneField(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="ai_chat_control",
    )
    force_human = models.BooleanField(default=False)
    updated_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="patient_ai_control_updates",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "patient_ai_conversation_controls"
        indexes = [
            models.Index(fields=["tenant", "force_human"]),
        ]

    def __str__(self) -> str:
        mode = "human" if self.force_human else "ai"
        return f"{self.patient_id}:{mode}"


class PatientAIMessage(models.Model):
    class RoleChoices(models.TextChoices):
        USER = "user", "User"
        ASSISTANT = "assistant", "Assistant"

    class SourceChoices(models.TextChoices):
        PATIENT = "patient", "Patient"
        AI = "ai", "AI"
        STAFF = "staff", "Staff"
        SYSTEM = "system", "System"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="patient_ai_messages",
    )
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="ai_messages",
    )
    role = models.CharField(max_length=20, choices=RoleChoices.choices)
    source = models.CharField(
        max_length=20,
        choices=SourceChoices.choices,
        default=SourceChoices.AI,
    )
    sender_user = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="sent_patient_ai_messages",
    )
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "patient_ai_messages"
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["patient", "created_at"]),
            models.Index(fields=["tenant", "created_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.patient_id}:{self.role}"


class PatientAITypingStatus(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="patient_ai_typing_statuses",
    )
    patient = models.OneToOneField(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="ai_typing_status",
    )
    is_typing = models.BooleanField(default=False)
    typed_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="patient_ai_typing_updates",
    )
    expires_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "patient_ai_typing_status"
        indexes = [
            models.Index(fields=["tenant", "expires_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.patient_id}:{'typing' if self.is_typing else 'idle'}"
