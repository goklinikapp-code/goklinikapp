from __future__ import annotations

from datetime import datetime

from rest_framework import serializers
from django.utils import timezone

from config.media_urls import AbsoluteMediaUrlsSerializerMixin

from apps.users.models import GoKlinikUser

from .models import Appointment


ALLOWED_STATUS_TRANSITIONS = {
    Appointment.StatusChoices.PENDING: {
        Appointment.StatusChoices.CONFIRMED,
        Appointment.StatusChoices.CANCELLED,
        Appointment.StatusChoices.RESCHEDULED,
    },
    Appointment.StatusChoices.CONFIRMED: {
        Appointment.StatusChoices.IN_PROGRESS,
        Appointment.StatusChoices.CANCELLED,
        Appointment.StatusChoices.RESCHEDULED,
    },
    Appointment.StatusChoices.IN_PROGRESS: {
        Appointment.StatusChoices.COMPLETED,
        Appointment.StatusChoices.CANCELLED,
    },
    Appointment.StatusChoices.COMPLETED: set(),
    Appointment.StatusChoices.CANCELLED: set(),
    Appointment.StatusChoices.RESCHEDULED: {
        Appointment.StatusChoices.PENDING,
        Appointment.StatusChoices.CONFIRMED,
    },
}


class AppointmentSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    patient_name = serializers.CharField(source="patient.full_name", read_only=True)
    patient_avatar_url = serializers.CharField(
        source="patient.avatar_url",
        read_only=True,
        allow_blank=True,
        allow_null=True,
    )
    professional_name = serializers.CharField(source="professional.full_name", read_only=True)
    professional_role = serializers.CharField(source="professional.role", read_only=True)
    professional_avatar_url = serializers.CharField(
        source="professional.avatar_url",
        read_only=True,
        allow_blank=True,
        allow_null=True,
    )
    specialty_name = serializers.CharField(source="specialty.specialty_name", read_only=True)

    class Meta:
        model = Appointment
        fields = (
            "id",
            "tenant",
            "patient",
            "patient_name",
            "patient_avatar_url",
            "professional",
            "professional_name",
            "professional_role",
            "professional_avatar_url",
            "specialty",
            "specialty_name",
            "appointment_date",
            "appointment_time",
            "duration_minutes",
            "status",
            "appointment_type",
            "clinic_location",
            "notes",
            "internal_notes",
            "cancellation_reason",
            "created_by",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "tenant",
            "created_by",
            "created_at",
            "updated_at",
            "cancellation_reason",
        )

    def validate_professional(self, value):
        if value.role != GoKlinikUser.RoleChoices.SURGEON:
            raise serializers.ValidationError("Selected professional must be a surgeon.")
        return value

    def validate(self, attrs):
        request = self.context["request"]
        user = request.user
        tenant = user.tenant

        patient = attrs.get("patient")
        professional = attrs.get("professional")
        specialty = attrs.get("specialty")
        clinic_location = (attrs.get("clinic_location") or "").strip()

        if not professional:
            raise serializers.ValidationError({"professional": "Professional is required."})
        if not patient:
            raise serializers.ValidationError({"patient": "Patient is required."})

        if user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            if not tenant:
                raise serializers.ValidationError("User has no tenant configured.")
            attrs["tenant"] = tenant

            if patient and patient.tenant_id != tenant.id:
                raise serializers.ValidationError({"patient": "Patient must belong to your tenant."})
            if professional and professional.tenant_id != tenant.id:
                raise serializers.ValidationError(
                    {"professional": "Professional must belong to your tenant."}
                )
            if specialty and specialty.tenant_id != tenant.id:
                raise serializers.ValidationError(
                    {"specialty": "Specialty must belong to your tenant."}
                )
        else:
            if patient:
                attrs["tenant"] = patient.tenant
            elif professional:
                attrs["tenant"] = professional.tenant

        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            if not patient or str(patient.id) != str(user.id):
                raise serializers.ValidationError(
                    {"patient": "Patient users can only create their own appointments."}
                )

        tenant_for_location = attrs.get("tenant")
        tenant_addresses = []
        if tenant_for_location and isinstance(tenant_for_location.clinic_addresses, list):
            tenant_addresses = [
                str(item).strip()
                for item in tenant_for_location.clinic_addresses
                if str(item).strip()
            ]

        if clinic_location:
            attrs["clinic_location"] = clinic_location
            if tenant_addresses and clinic_location not in tenant_addresses:
                raise serializers.ValidationError(
                    {"clinic_location": "Choose a valid clinic address from your tenant."}
                )
        elif tenant_addresses:
            attrs["clinic_location"] = tenant_addresses[0]

        if attrs.get("appointment_date") and attrs.get("appointment_time"):
            starts_at = datetime.combine(attrs["appointment_date"], attrs["appointment_time"])
            if starts_at < timezone.localtime().replace(tzinfo=None):
                raise serializers.ValidationError("Appointment cannot be created in the past.")

        return attrs


class AppointmentStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Appointment.StatusChoices.choices)
    internal_notes = serializers.CharField(required=False, allow_blank=True)

    def validate(self, attrs):
        appointment: Appointment = self.context["appointment"]
        new_status = attrs["status"]

        allowed = ALLOWED_STATUS_TRANSITIONS.get(appointment.status, set())
        if new_status not in allowed and new_status != appointment.status:
            raise serializers.ValidationError(
                f"Invalid transition from {appointment.status} to {new_status}."
            )
        return attrs


class AppointmentCancelSerializer(serializers.Serializer):
    reason = serializers.CharField()
