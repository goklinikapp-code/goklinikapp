from __future__ import annotations

from django.utils.crypto import get_random_string
from rest_framework import serializers

from config.media_urls import AbsoluteMediaUrlsSerializerMixin

from apps.tenants.models import Tenant
from apps.tenants.models import TenantSpecialty
from apps.users.models import GoKlinikUser
from apps.appointments.models import Appointment
from apps.pre_operatory.models import PreOperatory

from .models import Patient


def _latest_pre_operatory_for_patient(obj: Patient) -> PreOperatory | None:
    prefetched = getattr(obj, "_prefetched_objects_cache", {}).get(
        "pre_operatory_records"
    )
    if prefetched is not None:
        if not prefetched:
            return None
        return max(prefetched, key=lambda row: row.updated_at)

    return (
        PreOperatory.objects.select_related("procedure")
        .filter(patient_id=obj.id)
        .only(
            "status",
            "updated_at",
            "procedure_id",
            "procedure__specialty_name",
        )
        .order_by("-updated_at")
        .first()
    )


class PatientListSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    full_name = serializers.CharField(read_only=True)
    specialty_name = serializers.CharField(source="specialty.specialty_name", read_only=True)
    assigned_doctor = serializers.SerializerMethodField()
    pre_operatory_status = serializers.SerializerMethodField()
    pre_operatory_procedure_name = serializers.SerializerMethodField()
    has_active_appointment = serializers.SerializerMethodField()
    has_completed_surgery = serializers.SerializerMethodField()

    class Meta:
        model = Patient
        fields = (
            "id",
            "full_name",
            "email",
            "phone",
            "avatar_url",
            "status",
            "specialty",
            "specialty_name",
            "assigned_doctor",
            "pre_operatory_status",
            "pre_operatory_procedure_name",
            "app_installed_at",
            "last_app_login_at",
            "has_active_appointment",
            "has_completed_surgery",
            "date_joined",
        )

    def get_assigned_doctor(self, obj: Patient):
        assignment = getattr(obj, "doctor_assignment", None)
        if not assignment or not assignment.doctor_id:
            return None

        doctor = assignment.doctor
        return {
            "id": str(doctor.id),
            "name": doctor.full_name,
            "email": doctor.email,
            "phone": doctor.phone or "",
            "specialty": "Cirurgiao",
            "notes": assignment.notes or "",
            "assigned_at": assignment.assigned_at,
        }

    def get_pre_operatory_status(self, obj: Patient):
        latest = _latest_pre_operatory_for_patient(obj)
        return latest.status if latest else None

    def get_pre_operatory_procedure_name(self, obj: Patient):
        latest = _latest_pre_operatory_for_patient(obj)
        if not latest or not latest.procedure:
            return ""
        return latest.procedure.specialty_name or ""

    def get_has_active_appointment(self, obj: Patient):
        annotated = getattr(obj, "has_active_appointment", None)
        if annotated is not None:
            return bool(annotated)

        return Appointment.objects.filter(
            patient_id=obj.id,
            status__in=[
                Appointment.StatusChoices.PENDING,
                Appointment.StatusChoices.CONFIRMED,
                Appointment.StatusChoices.IN_PROGRESS,
                Appointment.StatusChoices.RESCHEDULED,
            ],
        ).exists()

    def get_has_completed_surgery(self, obj: Patient):
        annotated = getattr(obj, "has_completed_surgery", None)
        if annotated is not None:
            return bool(annotated)

        return Appointment.objects.filter(
            patient_id=obj.id,
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            status=Appointment.StatusChoices.COMPLETED,
        ).exists()


class PatientDetailSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    full_name = serializers.CharField(read_only=True)
    specialty_name = serializers.CharField(source="specialty.specialty_name", read_only=True)
    assigned_doctor = serializers.SerializerMethodField()
    pre_operatory_status = serializers.SerializerMethodField()
    pre_operatory_procedure_name = serializers.SerializerMethodField()
    has_active_appointment = serializers.SerializerMethodField()
    has_completed_surgery = serializers.SerializerMethodField()

    class Meta:
        model = Patient
        fields = (
            "id",
            "full_name",
            "first_name",
            "last_name",
            "email",
            "phone",
            "cpf",
            "date_of_birth",
            "avatar_url",
            "blood_type",
            "allergies",
            "previous_surgeries",
            "current_medications",
            "emergency_contact_name",
            "emergency_contact_phone",
            "emergency_contact_relation",
            "health_insurance",
            "referral_source",
            "status",
            "specialty",
            "specialty_name",
            "notes",
            "assigned_doctor",
            "pre_operatory_status",
            "pre_operatory_procedure_name",
            "app_installed_at",
            "last_app_login_at",
            "has_active_appointment",
            "has_completed_surgery",
            "tenant",
            "date_joined",
        )
        read_only_fields = ("id", "tenant", "date_joined")

    def get_assigned_doctor(self, obj: Patient):
        assignment = getattr(obj, "doctor_assignment", None)
        if not assignment or not assignment.doctor_id:
            return None

        doctor = assignment.doctor
        return {
            "id": str(doctor.id),
            "name": doctor.full_name,
            "email": doctor.email,
            "phone": doctor.phone or "",
            "specialty": "Cirurgiao",
            "notes": assignment.notes or "",
            "assigned_at": assignment.assigned_at,
        }

    def get_pre_operatory_status(self, obj: Patient):
        latest = _latest_pre_operatory_for_patient(obj)
        return latest.status if latest else None

    def get_pre_operatory_procedure_name(self, obj: Patient):
        latest = _latest_pre_operatory_for_patient(obj)
        if not latest or not latest.procedure:
            return ""
        return latest.procedure.specialty_name or ""

    def get_has_active_appointment(self, obj: Patient):
        annotated = getattr(obj, "has_active_appointment", None)
        if annotated is not None:
            return bool(annotated)

        return Appointment.objects.filter(
            patient_id=obj.id,
            status__in=[
                Appointment.StatusChoices.PENDING,
                Appointment.StatusChoices.CONFIRMED,
                Appointment.StatusChoices.IN_PROGRESS,
                Appointment.StatusChoices.RESCHEDULED,
            ],
        ).exists()

    def get_has_completed_surgery(self, obj: Patient):
        annotated = getattr(obj, "has_completed_surgery", None)
        if annotated is not None:
            return bool(annotated)

        return Appointment.objects.filter(
            patient_id=obj.id,
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            status=Appointment.StatusChoices.COMPLETED,
        ).exists()


class PatientCreateUpdateSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(write_only=True, required=False)
    specialty_name = serializers.CharField(write_only=True, required=False, allow_blank=True)
    referral_source = serializers.CharField(write_only=True, required=False, allow_blank=True)
    password = serializers.CharField(write_only=True, required=False, min_length=8)
    tenant = serializers.PrimaryKeyRelatedField(
        queryset=Tenant.objects.filter(is_active=True),
        required=False,
        write_only=True,
    )

    REFERRAL_SOURCE_MAP = {
        "instagram": Patient.ReferralSourceChoices.INSTAGRAM,
        "indication": Patient.ReferralSourceChoices.INDICATION,
        "indicacao": Patient.ReferralSourceChoices.INDICATION,
        "indicação": Patient.ReferralSourceChoices.INDICATION,
        "google": Patient.ReferralSourceChoices.GOOGLE,
        "other": Patient.ReferralSourceChoices.OTHER,
        "outro": Patient.ReferralSourceChoices.OTHER,
    }

    class Meta:
        model = Patient
        fields = (
            "full_name",
            "first_name",
            "last_name",
            "email",
            "phone",
            "cpf",
            "date_of_birth",
            "avatar_url",
            "password",
            "blood_type",
            "allergies",
            "previous_surgeries",
            "current_medications",
            "emergency_contact_name",
            "emergency_contact_phone",
            "emergency_contact_relation",
            "health_insurance",
            "referral_source",
            "status",
            "specialty",
            "specialty_name",
            "tenant",
            "notes",
            "is_active",
        )

    def validate_specialty(self, value: TenantSpecialty | None):
        request = self.context["request"]
        user = request.user
        if value is None or user.role == "super_admin":
            return value
        if not user.tenant_id or value.tenant_id != user.tenant_id:
            raise serializers.ValidationError("Specialty must belong to the same tenant.")
        return value

    def _set_names(self, validated_data: dict):
        full_name = validated_data.pop("full_name", "").strip()
        if full_name:
            parts = full_name.split()
            validated_data["first_name"] = parts[0]
            validated_data["last_name"] = " ".join(parts[1:]) if len(parts) > 1 else ""

    def _normalize_referral_source(self, validated_data: dict, *, default_if_missing: bool):
        if "referral_source" not in validated_data:
            if default_if_missing:
                validated_data["referral_source"] = Patient.ReferralSourceChoices.OTHER
            return

        raw_source = str(validated_data.get("referral_source", "")).strip().lower()
        if not raw_source:
            validated_data["referral_source"] = Patient.ReferralSourceChoices.OTHER
            return

        normalized = self.REFERRAL_SOURCE_MAP.get(raw_source)
        if not normalized:
            raise serializers.ValidationError(
                {
                    "referral_source": (
                        "Invalid referral source. Use: instagram, indication, google, or other."
                    )
                }
            )
        validated_data["referral_source"] = normalized

    def _resolve_specialty_by_name(self, validated_data: dict, tenant: Tenant):
        if validated_data.get("specialty"):
            validated_data.pop("specialty_name", None)
            return

        specialty_name = str(validated_data.pop("specialty_name", "")).strip()
        if not specialty_name:
            return

        specialty = TenantSpecialty.objects.filter(
            tenant=tenant,
            specialty_name__iexact=specialty_name,
            is_active=True,
        ).first()
        if not specialty:
            raise serializers.ValidationError(
                {"specialty_name": "Specialty not found for this tenant."}
            )
        validated_data["specialty"] = specialty

    def create(self, validated_data):
        self._set_names(validated_data)
        request = self.context["request"]
        password = validated_data.pop("password", None) or get_random_string(12)
        requested_tenant = validated_data.pop("tenant", None)

        if request.user.role == GoKlinikUser.RoleChoices.SUPER_ADMIN:
            resolved_tenant = (
                requested_tenant
                or request.user.tenant
                or Tenant.objects.filter(is_active=True).order_by("created_at").first()
            )
        else:
            resolved_tenant = request.user.tenant

        if not resolved_tenant:
            raise serializers.ValidationError(
                {"tenant": "Tenant is required to create a patient."}
            )

        self._normalize_referral_source(validated_data, default_if_missing=True)
        self._resolve_specialty_by_name(validated_data, resolved_tenant)

        validated_data["tenant"] = resolved_tenant
        validated_data["role"] = Patient.RoleChoices.PATIENT

        patient = Patient(**validated_data)
        patient.set_password(password)
        patient.save()
        return patient

    def update(self, instance, validated_data):
        self._set_names(validated_data)
        self._normalize_referral_source(validated_data, default_if_missing=False)
        self._resolve_specialty_by_name(validated_data, instance.tenant)

        password = validated_data.pop("password", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        if password:
            instance.set_password(password)

        instance.save()
        return instance


class AssignDoctorSerializer(serializers.Serializer):
    doctor_id = serializers.UUIDField()
    notes = serializers.CharField(required=False, allow_blank=True, default="")
