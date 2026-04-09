from __future__ import annotations

from datetime import datetime

from rest_framework import serializers
from django.utils import timezone

from config.media_urls import AbsoluteMediaUrlsSerializerMixin

from apps.users.models import GoKlinikUser

from .models import Appointment, BlockedPeriod, ProfessionalAvailability


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

ACTIVE_APPOINTMENT_STATUSES = {
    Appointment.StatusChoices.PENDING,
    Appointment.StatusChoices.CONFIRMED,
    Appointment.StatusChoices.IN_PROGRESS,
}

RETURN_FLOW_RELEVANT_STATUSES = {
    Appointment.StatusChoices.PENDING,
    Appointment.StatusChoices.CONFIRMED,
    Appointment.StatusChoices.IN_PROGRESS,
    Appointment.StatusChoices.COMPLETED,
}

PRIMARY_FLOW_APPOINTMENT_TYPES = {
    Appointment.AppointmentTypeChoices.FIRST_VISIT,
    Appointment.AppointmentTypeChoices.RETURN,
    Appointment.AppointmentTypeChoices.SURGERY,
}

POST_OP_APPOINTMENT_TYPES = {
    Appointment.AppointmentTypeChoices.POST_OP_7D,
    Appointment.AppointmentTypeChoices.POST_OP_30D,
    Appointment.AppointmentTypeChoices.POST_OP_90D,
}


def _build_active_patient_queryset(*, patient_id, exclude_appointment_id=None):
    queryset = Appointment.objects.filter(
        patient_id=patient_id,
        status__in=ACTIVE_APPOINTMENT_STATUSES,
    )
    if exclude_appointment_id:
        queryset = queryset.exclude(id=exclude_appointment_id)
    return queryset


def _validate_patient_appointment_flow(
    *,
    patient,
    appointment_type: str,
    status_value: str,
    exclude_appointment_id=None,
) -> None:
    if not patient:
        return

    if status_value in {
        Appointment.StatusChoices.CANCELLED,
        Appointment.StatusChoices.RESCHEDULED,
    }:
        return

    patient_id = patient.id
    active_qs = _build_active_patient_queryset(
        patient_id=patient_id,
        exclude_appointment_id=exclude_appointment_id,
    )

    if status_value in ACTIVE_APPOINTMENT_STATUSES:
        if active_qs.filter(appointment_type=appointment_type).exists():
            raise serializers.ValidationError(
                {
                    "appointment_type": (
                        "Este paciente já possui um agendamento ativo deste tipo. "
                        "Conclua, cancele ou remarque o atual antes de criar outro."
                    )
                }
            )

        if appointment_type in PRIMARY_FLOW_APPOINTMENT_TYPES:
            active_primary = (
                active_qs.filter(appointment_type__in=PRIMARY_FLOW_APPOINTMENT_TYPES)
                .order_by("appointment_date", "appointment_time")
                .first()
            )
            if active_primary:
                raise serializers.ValidationError(
                    {
                        "patient": (
                            "Este paciente já possui um agendamento ativo no fluxo principal "
                            f"({active_primary.get_appointment_type_display()}). "
                            "Conclua, cancele ou remarque o atual antes de criar outro "
                            "de Primeira Consulta, Retorno ou Cirurgia."
                        )
                    }
                )

    if appointment_type == Appointment.AppointmentTypeChoices.RETURN:
        has_completed_first_visit = Appointment.objects.filter(
            patient_id=patient_id,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            status=Appointment.StatusChoices.COMPLETED,
        ).exists()
        if not has_completed_first_visit:
            raise serializers.ValidationError(
                {
                    "appointment_type": (
                        "Não é possível agendar Retorno antes de concluir a Primeira Consulta."
                    )
                }
            )

    if appointment_type == Appointment.AppointmentTypeChoices.SURGERY:
        has_completed_first_visit = Appointment.objects.filter(
            patient_id=patient_id,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            status=Appointment.StatusChoices.COMPLETED,
        ).exists()
        if not has_completed_first_visit:
            raise serializers.ValidationError(
                {
                    "appointment_type": (
                        "Não é possível agendar Cirurgia antes de concluir a Primeira Consulta."
                    )
                }
            )

        has_any_return = Appointment.objects.filter(
            patient_id=patient_id,
            appointment_type=Appointment.AppointmentTypeChoices.RETURN,
            status__in=RETURN_FLOW_RELEVANT_STATUSES,
        ).exists()
        has_completed_return = Appointment.objects.filter(
            patient_id=patient_id,
            appointment_type=Appointment.AppointmentTypeChoices.RETURN,
            status=Appointment.StatusChoices.COMPLETED,
        ).exists()
        if has_any_return and not has_completed_return:
            raise serializers.ValidationError(
                {
                    "appointment_type": (
                        "Existe um Retorno em aberto para este paciente. "
                        "Conclua o Retorno antes de agendar a Cirurgia."
                    )
                }
            )

    if appointment_type in POST_OP_APPOINTMENT_TYPES:
        has_completed_surgery = Appointment.objects.filter(
            patient_id=patient_id,
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            status=Appointment.StatusChoices.COMPLETED,
        ).exists()
        if not has_completed_surgery:
            raise serializers.ValidationError(
                {
                    "appointment_type": (
                        "Não é possível agendar pós-operatório antes de uma Cirurgia concluída."
                    )
                }
            )


def _validate_surgery_completion_timing(
    *,
    appointment_type: str | None,
    status_value: str | None,
    appointment_date,
) -> None:
    if appointment_type != Appointment.AppointmentTypeChoices.SURGERY:
        return
    if status_value != Appointment.StatusChoices.COMPLETED:
        return
    if not appointment_date:
        return
    if appointment_date > timezone.localdate():
        raise serializers.ValidationError(
            {
                "status": "A cirurgia não pode ser concluída antes da data agendada."
            }
        )


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
            raise serializers.ValidationError("O profissional selecionado precisa ser um cirurgião.")
        return value

    def validate(self, attrs):
        request = self.context["request"]
        user = request.user
        tenant = user.tenant
        instance = getattr(self, "instance", None)

        patient = attrs.get("patient", getattr(instance, "patient", None))
        professional = attrs.get("professional", getattr(instance, "professional", None))
        specialty = attrs.get("specialty", getattr(instance, "specialty", None))
        clinic_location = (attrs.get("clinic_location", getattr(instance, "clinic_location", "")) or "").strip()
        target_status = attrs.get(
            "status",
            getattr(instance, "status", Appointment.StatusChoices.PENDING),
        )
        target_type = attrs.get(
            "appointment_type",
            getattr(instance, "appointment_type", Appointment.AppointmentTypeChoices.FIRST_VISIT),
        )
        exclude_appointment_id = getattr(instance, "id", None)

        if not professional:
            raise serializers.ValidationError({"professional": "Selecione um profissional para continuar."})
        if not patient:
            raise serializers.ValidationError({"patient": "Selecione um paciente para continuar."})

        if user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            if not tenant:
                raise serializers.ValidationError("Usuário sem clínica (tenant) configurada.")
            attrs["tenant"] = tenant

            if patient and patient.tenant_id != tenant.id:
                raise serializers.ValidationError({"patient": "O paciente precisa pertencer à sua clínica."})
            if professional and professional.tenant_id != tenant.id:
                raise serializers.ValidationError(
                    {"professional": "O profissional precisa pertencer à sua clínica."}
                )
            if specialty and specialty.tenant_id != tenant.id:
                raise serializers.ValidationError(
                    {"specialty": "A especialidade precisa pertencer à sua clínica."}
                )
        else:
            if patient:
                attrs["tenant"] = patient.tenant
            elif professional:
                attrs["tenant"] = professional.tenant

        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            if not patient or str(patient.id) != str(user.id):
                raise serializers.ValidationError(
                    {"patient": "Pacientes só podem criar agendamentos para o próprio perfil."}
                )
        if user.role == GoKlinikUser.RoleChoices.SURGEON:
            if not professional or str(professional.id) != str(user.id):
                raise serializers.ValidationError(
                    {"professional": "Cirurgiões só podem agendar consultas para si mesmos."}
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
                    {"clinic_location": "Selecione um endereço válido da sua clínica."}
                )
        elif tenant_addresses:
            attrs["clinic_location"] = tenant_addresses[0]

        if attrs.get("appointment_date") and attrs.get("appointment_time"):
            starts_at = datetime.combine(attrs["appointment_date"], attrs["appointment_time"])
            if starts_at < timezone.localtime().replace(tzinfo=None):
                raise serializers.ValidationError("Não é possível criar agendamento em data/hora passada.")

        _validate_surgery_completion_timing(
            appointment_type=attrs.get(
                "appointment_type",
                getattr(instance, "appointment_type", None),
            ),
            status_value=attrs.get("status", getattr(instance, "status", None)),
            appointment_date=attrs.get(
                "appointment_date",
                getattr(instance, "appointment_date", None),
            ),
        )

        should_validate_flow = instance is None
        if instance is not None:
            status_will_be_active = target_status in ACTIVE_APPOINTMENT_STATUSES
            type_changed = (
                "appointment_type" in attrs
                and target_type != instance.appointment_type
            )
            status_changed_to_active = (
                "status" in attrs
                and status_will_be_active
                and instance.status not in ACTIVE_APPOINTMENT_STATUSES
            )
            should_validate_flow = type_changed or status_changed_to_active

        if should_validate_flow:
            _validate_patient_appointment_flow(
                patient=patient,
                appointment_type=target_type,
                status_value=target_status,
                exclude_appointment_id=exclude_appointment_id,
            )

        return attrs


class AppointmentStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Appointment.StatusChoices.choices)
    internal_notes = serializers.CharField(required=False, allow_blank=True)

    def validate(self, attrs):
        appointment: Appointment = self.context["appointment"]
        new_status = attrs["status"]

        _validate_surgery_completion_timing(
            appointment_type=appointment.appointment_type,
            status_value=new_status,
            appointment_date=appointment.appointment_date,
        )

        # Allow quick-complete flow for surgeries from schedule cards.
        if (
            appointment.appointment_type == Appointment.AppointmentTypeChoices.SURGERY
            and new_status == Appointment.StatusChoices.COMPLETED
            and appointment.status
            in {
                Appointment.StatusChoices.PENDING,
                Appointment.StatusChoices.CONFIRMED,
                Appointment.StatusChoices.IN_PROGRESS,
            }
        ):
            return attrs

        allowed = ALLOWED_STATUS_TRANSITIONS.get(appointment.status, set())
        if new_status not in allowed and new_status != appointment.status:
            raise serializers.ValidationError(
                f"Transição de status inválida: {appointment.status} -> {new_status}."
            )
        return attrs


class AppointmentCancelSerializer(serializers.Serializer):
    reason = serializers.CharField()


class ProfessionalAvailabilitySerializer(serializers.ModelSerializer):
    class Meta:
        model = ProfessionalAvailability
        fields = (
            "id",
            "day_of_week",
            "start_time",
            "end_time",
            "is_active",
        )
        read_only_fields = ("id",)


class ProfessionalAvailabilityRuleSerializer(serializers.Serializer):
    day_of_week = serializers.ChoiceField(choices=ProfessionalAvailability.DAYS)
    start_time = serializers.TimeField()
    end_time = serializers.TimeField()
    is_active = serializers.BooleanField(default=True)

    def validate(self, attrs):
        start_time = attrs["start_time"]
        end_time = attrs["end_time"]
        if start_time >= end_time:
            raise serializers.ValidationError(
                {"end_time": "End time must be later than start time."}
            )
        return attrs


class ProfessionalAvailabilityBulkUpdateSerializer(serializers.Serializer):
    professional_id = serializers.UUIDField(required=False)
    rules = ProfessionalAvailabilityRuleSerializer(many=True, required=False)

    def validate_rules(self, value):
        windows_by_day: dict[int, list[tuple[object, object]]] = {}
        for item in value:
            if not item.get("is_active", True):
                continue
            day = int(item["day_of_week"])
            windows_by_day.setdefault(day, []).append(
                (item["start_time"], item["end_time"])
            )

        for day, windows in windows_by_day.items():
            ordered = sorted(windows, key=lambda row: row[0])
            for index in range(1, len(ordered)):
                previous_end = ordered[index - 1][1]
                current_start = ordered[index][0]
                if current_start < previous_end:
                    raise serializers.ValidationError(
                        f"Overlapping active intervals for day_of_week={day}."
                    )
        return value


class BlockedPeriodSerializer(serializers.ModelSerializer):
    professional_name = serializers.CharField(
        source="professional.full_name",
        read_only=True,
    )

    class Meta:
        model = BlockedPeriod
        fields = (
            "id",
            "professional",
            "professional_name",
            "start_datetime",
            "end_datetime",
            "reason",
        )
        read_only_fields = ("id", "professional_name")


class BlockedPeriodCreateSerializer(serializers.Serializer):
    professional_id = serializers.UUIDField(required=False)
    start_datetime = serializers.DateTimeField()
    end_datetime = serializers.DateTimeField()
    reason = serializers.CharField(max_length=255)

    def validate(self, attrs):
        start_datetime = attrs["start_datetime"]
        end_datetime = attrs["end_datetime"]
        if start_datetime >= end_datetime:
            raise serializers.ValidationError(
                {"end_datetime": "End datetime must be later than start datetime."}
            )
        attrs["reason"] = (attrs.get("reason") or "").strip()
        if not attrs["reason"]:
            raise serializers.ValidationError({"reason": "Reason is required."})
        return attrs


class BlockedPeriodDeleteSerializer(serializers.Serializer):
    id = serializers.UUIDField()
