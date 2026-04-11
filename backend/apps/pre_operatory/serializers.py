from __future__ import annotations

from rest_framework import serializers

from config.media_urls import AbsoluteMediaUrlsSerializerMixin
from apps.patients.models import DoctorPatientAssignment
from apps.tenants.models import TenantSpecialty

from .models import PreOperatory, PreOperatoryFile


class LenientFloatField(serializers.FloatField):
    """Accept both comma and dot as decimal separator."""

    def to_internal_value(self, data):
        if data is None:
            return None

        if isinstance(data, str):
            normalized = data.strip()
            if not normalized:
                return None
            data = normalized.replace(",", ".")

        return super().to_internal_value(data)


class PreOperatoryFileSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    class Meta:
        model = PreOperatoryFile
        fields = ("id", "file_url", "type", "created_at")
        read_only_fields = fields


class PreOperatorySerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    files = PreOperatoryFileSerializer(many=True, read_only=True)
    photos = serializers.SerializerMethodField()
    documents = serializers.SerializerMethodField()
    smokes = serializers.SerializerMethodField()
    drinks_alcohol = serializers.SerializerMethodField()
    patient_name = serializers.CharField(source="patient.full_name", read_only=True)
    patient_avatar_url = serializers.CharField(
        source="patient.avatar_url",
        read_only=True,
        allow_blank=True,
        allow_null=True,
    )
    assigned_doctor_name = serializers.CharField(
        source="assigned_doctor.full_name",
        read_only=True,
        allow_null=True,
    )
    approved_by_name = serializers.CharField(
        source="approved_by.full_name",
        read_only=True,
        allow_null=True,
    )
    current_doctor_id = serializers.SerializerMethodField()
    current_doctor_name = serializers.SerializerMethodField()
    approved_by_different_doctor = serializers.SerializerMethodField()
    procedure_name = serializers.CharField(
        source="procedure.specialty_name",
        read_only=True,
        allow_null=True,
    )
    procedure_description = serializers.CharField(
        source="procedure.description",
        read_only=True,
        allow_blank=True,
        allow_null=True,
    )

    class Meta:
        model = PreOperatory
        fields = (
            "id",
            "patient",
            "patient_name",
            "patient_avatar_url",
            "tenant",
            "allergies",
            "medications",
            "previous_surgeries",
            "diseases",
            "smoking",
            "alcohol",
            "smokes",
            "drinks_alcohol",
            "height",
            "weight",
            "notes",
            "procedure",
            "procedure_name",
            "procedure_description",
            "assigned_doctor",
            "assigned_doctor_name",
            "approved_by_name",
            "current_doctor_id",
            "current_doctor_name",
            "approved_by_different_doctor",
            "status",
            "approved_at",
            "files",
            "photos",
            "documents",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "patient",
            "tenant",
            "status",
            "approved_at",
            "files",
            "photos",
            "documents",
            "created_at",
            "updated_at",
        )

    def _get_current_assignment(self, obj: PreOperatory):
        assignment = getattr(obj, "_current_doctor_assignment", None)
        if assignment is not None:
            return assignment

        assignment = (
            DoctorPatientAssignment.objects.select_related("doctor")
            .filter(patient_id=obj.patient_id)
            .first()
        )
        setattr(obj, "_current_doctor_assignment", assignment)
        return assignment

    def get_photos(self, obj: PreOperatory):
        rows = obj.files.filter(type=PreOperatoryFile.FileTypeChoices.PHOTO)
        return PreOperatoryFileSerializer(
            rows,
            many=True,
            context=self.context,
        ).data

    def get_documents(self, obj: PreOperatory):
        rows = obj.files.filter(type=PreOperatoryFile.FileTypeChoices.DOCUMENT)
        return PreOperatoryFileSerializer(
            rows,
            many=True,
            context=self.context,
        ).data

    def get_smokes(self, obj: PreOperatory) -> bool:
        return bool(obj.smoking)

    def get_drinks_alcohol(self, obj: PreOperatory) -> bool:
        return bool(obj.alcohol)

    def get_current_doctor_name(self, obj: PreOperatory):
        assignment = self._get_current_assignment(obj)
        if not assignment or not assignment.doctor_id:
            return None
        return assignment.doctor.full_name

    def get_current_doctor_id(self, obj: PreOperatory):
        assignment = self._get_current_assignment(obj)
        if not assignment or not assignment.doctor_id:
            return None
        return str(assignment.doctor_id)

    def get_approved_by_different_doctor(self, obj: PreOperatory) -> bool:
        if not obj.approved_by_id:
            return False

        assignment = self._get_current_assignment(obj)
        if not assignment or not assignment.doctor_id:
            return False

        return str(obj.approved_by_id) != str(assignment.doctor_id)


class PreOperatoryWriteSerializer(serializers.ModelSerializer):
    height = LenientFloatField(required=False, allow_null=True)
    weight = LenientFloatField(required=False, allow_null=True)
    procedure = serializers.PrimaryKeyRelatedField(
        queryset=TenantSpecialty.objects.none(),
        required=False,
        allow_null=True,
    )
    photos = serializers.ListField(
        child=serializers.FileField(),
        required=False,
        allow_empty=True,
    )
    documents = serializers.ListField(
        child=serializers.FileField(),
        required=False,
        allow_empty=True,
    )

    class Meta:
        model = PreOperatory
        fields = (
            "allergies",
            "medications",
            "previous_surgeries",
            "diseases",
            "smoking",
            "alcohol",
            "height",
            "weight",
            "procedure",
            "photos",
            "documents",
        )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        tenant_id = self.context.get("tenant_id")
        queryset = TenantSpecialty.objects.none()
        if tenant_id:
            queryset = TenantSpecialty.objects.filter(
                tenant_id=tenant_id,
                is_active=True,
            )
        self.fields["procedure"].queryset = queryset.order_by(
            "display_order",
            "specialty_name",
        )

    def validate_allergies(self, value: str) -> str:
        return (value or "").strip()

    def validate_medications(self, value: str) -> str:
        return (value or "").strip()

    def validate_previous_surgeries(self, value: str) -> str:
        return (value or "").strip()

    def validate_diseases(self, value: str) -> str:
        return (value or "").strip()

    def validate_height(self, value):
        if value is None:
            return value
        if value <= 0:
            raise serializers.ValidationError("Height must be greater than zero.")
        return value

    def validate_weight(self, value):
        if value is None:
            return value
        if value <= 0:
            raise serializers.ValidationError("Weight must be greater than zero.")
        return value

    def validate(self, attrs):
        attrs = super().validate(attrs)
        instance = getattr(self, "instance", None)
        errors = {}

        if instance is None:
            if attrs.get("height") is None:
                errors["height"] = "Height is required."
            if attrs.get("weight") is None:
                errors["weight"] = "Weight is required."
            if attrs.get("procedure") is None:
                errors["procedure"] = "Procedure selection is required."
        else:
            if "height" in attrs and attrs.get("height") is None:
                errors["height"] = "Height is required."
            if "weight" in attrs and attrs.get("weight") is None:
                errors["weight"] = "Weight is required."
            if "procedure" in attrs and attrs.get("procedure") is None:
                errors["procedure"] = "Procedure selection is required."

        if errors:
            raise serializers.ValidationError(errors)

        return attrs


class PreOperatoryAdminUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=PreOperatory.StatusChoices.choices,
        required=False,
    )
    notes = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
    )
    assigned_doctor = serializers.UUIDField(
        required=False,
        allow_null=True,
    )
