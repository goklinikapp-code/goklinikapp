from __future__ import annotations

import re

from django.utils import timezone
from rest_framework import serializers

from .models import (
    Notification,
    NotificationLog,
    NotificationTemplate,
    NotificationToken,
    NotificationWorkflow,
    ScheduledNotification,
)

SUPPORTED_PUSH_SEGMENTS = (
    "all_patients",
    "future_appointments",
    "inactive_patients",
)
OFFSET_PATTERN = re.compile(r"^\s*(\d+)\s*([mhd])\s*$", re.IGNORECASE)
TEMPLATE_CODE_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_-]{2,59}$")


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


class NotificationTemplateSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationTemplate
        fields = (
            "id",
            "code",
            "title_template",
            "body_template",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")

    def validate_code(self, value: str) -> str:
        normalized = (value or "").strip().lower().replace(" ", "_")
        if not TEMPLATE_CODE_PATTERN.match(normalized):
            raise serializers.ValidationError(
                "Use apenas letras minúsculas, números, _ ou -. Mínimo 3 caracteres."
            )

        request = self.context.get("request")
        tenant_id = getattr(getattr(request, "user", None), "tenant_id", None)
        if not tenant_id:
            return normalized

        queryset = NotificationTemplate.objects.filter(
            tenant_id=tenant_id,
            code=normalized,
        )
        if self.instance:
            queryset = queryset.exclude(id=self.instance.id)
        if queryset.exists():
            raise serializers.ValidationError("Já existe um template com esse código nesta clínica.")
        return normalized

    def validate(self, attrs):
        request = self.context.get("request")
        tenant_id = getattr(getattr(request, "user", None), "tenant_id", None)
        if not tenant_id:
            raise serializers.ValidationError({"detail": "Clinic tenant not found."})

        current_title = getattr(self.instance, "title_template", "")
        current_body = getattr(self.instance, "body_template", "")
        attrs["title_template"] = (attrs.get("title_template", current_title) or "").strip()
        attrs["body_template"] = (attrs.get("body_template", current_body) or "").strip()

        if not attrs["title_template"]:
            raise serializers.ValidationError({"title_template": "Título do template é obrigatório."})
        if not attrs["body_template"]:
            raise serializers.ValidationError({"body_template": "Corpo do template é obrigatório."})

        return attrs


class NotificationLogSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.full_name", read_only=True)
    user_email = serializers.EmailField(source="user.email", read_only=True)

    class Meta:
        model = NotificationLog
        fields = (
            "id",
            "user",
            "user_name",
            "user_email",
            "title",
            "body",
            "channel",
            "status",
            "event_code",
            "segment",
            "data_extra",
            "error_message",
            "created_at",
        )
        read_only_fields = fields


class NotificationRecipientSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    full_name = serializers.CharField()
    email = serializers.EmailField()
    phone = serializers.CharField(allow_blank=True)
    has_active_push_token = serializers.BooleanField()
    active_push_tokens = serializers.IntegerField()


class NotificationBroadcastSerializer(serializers.Serializer):
    target_mode = serializers.ChoiceField(choices=("segment", "patient"), default="segment", required=False)
    patient_id = serializers.UUIDField(required=False)
    title = serializers.CharField(max_length=255, required=False, allow_blank=True)
    body = serializers.CharField(required=False, allow_blank=True)
    channel = serializers.CharField(default="push", required=False)
    segment = serializers.ChoiceField(choices=SUPPORTED_PUSH_SEGMENTS, required=False)
    template_code = serializers.CharField(max_length=60, required=False, allow_blank=True)
    template_context = serializers.DictField(
        child=serializers.CharField(allow_blank=True),
        required=False,
    )
    data_extra = serializers.DictField(
        child=serializers.CharField(allow_blank=True),
        required=False,
    )
    send_to_all = serializers.BooleanField(default=False, required=False)
    specialty_id = serializers.UUIDField(required=False, allow_null=True)

    def validate(self, attrs):
        channel = (attrs.get("channel") or "push").strip().lower()
        if channel != "push":
            raise serializers.ValidationError({"channel": "Only push channel is supported."})

        template_code = (attrs.get("template_code") or "").strip()
        title = (attrs.get("title") or "").strip()
        body = (attrs.get("body") or "").strip()

        if not template_code and (not title or not body):
            raise serializers.ValidationError(
                {"body": "Provide title/body or a template_code."}
            )

        target_mode = attrs.get("target_mode") or "segment"
        if target_mode == "patient":
            if not attrs.get("patient_id"):
                raise serializers.ValidationError({"patient_id": "patient_id is required for target_mode='patient'."})
            attrs["segment"] = "individual_patient"
        else:
            if "segment" not in attrs:
                attrs["segment"] = "all_patients"

        if attrs.get("specialty_id") and attrs.get("segment") == "inactive_patients":
            raise serializers.ValidationError(
                {"specialty_id": "Specialty filter is not supported for inactive_patients segment."}
            )

        attrs["target_mode"] = target_mode
        attrs["channel"] = "push"
        attrs["template_code"] = template_code
        attrs["title"] = title
        attrs["body"] = body
        attrs["template_context"] = attrs.get("template_context", {})
        attrs["data_extra"] = attrs.get("data_extra", {})
        return attrs


class NotificationWorkflowSerializer(serializers.ModelSerializer):
    template_code = serializers.CharField(source="template.code", read_only=True)

    class Meta:
        model = NotificationWorkflow
        fields = (
            "id",
            "name",
            "is_active",
            "trigger_type",
            "trigger_offset",
            "template",
            "template_code",
            "created_by",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_by", "created_at", "updated_at", "template_code")

    def validate(self, attrs):
        trigger_type = attrs.get("trigger_type", getattr(self.instance, "trigger_type", ""))
        trigger_offset = (attrs.get("trigger_offset", getattr(self.instance, "trigger_offset", "")) or "").strip().lower()
        template = attrs.get("template", getattr(self.instance, "template", None))
        request = self.context.get("request")
        tenant_id = getattr(getattr(request, "user", None), "tenant_id", None)

        if template:
            if template.tenant_id and tenant_id and str(template.tenant_id) != str(tenant_id):
                raise serializers.ValidationError({"template": "Template não pertence à clínica atual."})
            if not template.is_active:
                raise serializers.ValidationError({"template": "Template inativo não pode ser usado no workflow."})

        if trigger_type == NotificationWorkflow.TriggerTypeChoices.REMINDER_BEFORE and not trigger_offset:
            attrs["trigger_offset"] = "24h"
        elif trigger_type == NotificationWorkflow.TriggerTypeChoices.POST_OP_FOLLOWUP and not trigger_offset:
            attrs["trigger_offset"] = "7d"
        elif trigger_type == NotificationWorkflow.TriggerTypeChoices.APPOINTMENT_CREATED:
            attrs["trigger_offset"] = ""
        else:
            attrs["trigger_offset"] = trigger_offset

        normalized_offset = (attrs.get("trigger_offset") or "").strip().lower()
        if (
            trigger_type != NotificationWorkflow.TriggerTypeChoices.APPOINTMENT_CREATED
            and not OFFSET_PATTERN.match(normalized_offset)
        ):
            raise serializers.ValidationError(
                {"trigger_offset": "Invalid format. Use values like 24h, 7d or 30m."}
            )

        return attrs


class ScheduledNotificationSerializer(serializers.ModelSerializer):
    template_code = serializers.CharField(source="template.code", read_only=True)

    class Meta:
        model = ScheduledNotification
        fields = (
            "id",
            "run_at",
            "segment",
            "title",
            "body",
            "template",
            "template_code",
            "template_context",
            "data_extra",
            "status",
            "summary",
            "error_message",
            "processed_at",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "template_code",
            "status",
            "summary",
            "error_message",
            "processed_at",
            "created_at",
            "updated_at",
        )

    def validate(self, attrs):
        run_at = attrs.get("run_at", getattr(self.instance, "run_at", None))
        if run_at and timezone.is_naive(run_at):
            run_at = timezone.make_aware(run_at, timezone.get_current_timezone())
            attrs["run_at"] = run_at
        template = attrs.get("template", getattr(self.instance, "template", None))
        title = (attrs.get("title", getattr(self.instance, "title", "")) or "").strip()
        body = (attrs.get("body", getattr(self.instance, "body", "")) or "").strip()
        request = self.context.get("request")
        tenant_id = getattr(getattr(request, "user", None), "tenant_id", None)

        if template:
            if template.tenant_id and tenant_id and str(template.tenant_id) != str(tenant_id):
                raise serializers.ValidationError({"template": "Template não pertence à clínica atual."})
            if not template.is_active:
                raise serializers.ValidationError({"template": "Template inativo não pode ser usado no agendamento."})

        if run_at and run_at <= timezone.now():
            raise serializers.ValidationError({"run_at": "run_at must be in the future."})

        if not template and (not title or not body):
            raise serializers.ValidationError(
                {"body": "Provide title/body or select a template."}
            )

        attrs["title"] = title
        attrs["body"] = body
        attrs["template_context"] = attrs.get("template_context", {})
        attrs["data_extra"] = attrs.get("data_extra", {})
        return attrs
