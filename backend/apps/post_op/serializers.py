from __future__ import annotations

from rest_framework import serializers

from .models import EvolutionPhoto, PostOpChecklist, UrgentMedicalRequest


class PostOpChecklistSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostOpChecklist
        fields = ("id", "day_number", "item_text", "is_completed", "completed_at")
        read_only_fields = fields


class EvolutionPhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = EvolutionPhoto
        fields = (
            "id",
            "journey",
            "day_number",
            "photo_url",
            "uploaded_at",
            "is_visible_to_clinic",
            "is_anonymous",
        )
        read_only_fields = fields


class EvolutionPhotoCreateSerializer(serializers.Serializer):
    journey_id = serializers.UUIDField()
    day_number = serializers.IntegerField(min_value=1)
    photo = serializers.ImageField()
    is_anonymous = serializers.BooleanField(required=False, default=False)


class JourneyAppointmentSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    appointment_type = serializers.CharField()
    appointment_date = serializers.DateField()
    appointment_time = serializers.TimeField()
    professional_name = serializers.CharField(allow_blank=True, allow_null=True)


class JourneyChecklistDaySerializer(serializers.Serializer):
    day_number = serializers.IntegerField()
    title = serializers.CharField()
    description = serializers.CharField()
    is_milestone = serializers.BooleanField()
    status = serializers.ChoiceField(choices=("completed", "today", "upcoming"))
    checklist_items = PostOpChecklistSerializer(many=True)


class MyJourneyResponseSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    appointment = JourneyAppointmentSerializer()
    specialty = serializers.DictField()
    surgery_date = serializers.DateField()
    current_day = serializers.IntegerField()
    status = serializers.CharField()
    protocol = JourneyChecklistDaySerializer(many=True)


class AdminJourneySerializer(serializers.Serializer):
    id = serializers.UUIDField()
    patient_id = serializers.UUIDField()
    patient_name = serializers.CharField()
    procedure = serializers.CharField(allow_blank=True)
    surgery_date = serializers.DateField()
    current_day = serializers.IntegerField()
    checklist_completion_percent = serializers.FloatField()


class CareCenterFAQSerializer(serializers.Serializer):
    question = serializers.CharField()
    answer = serializers.CharField()


class CareCenterMedicationSerializer(serializers.Serializer):
    name = serializers.CharField()
    dosage = serializers.CharField()
    schedule = serializers.CharField()


class CareCenterResponseSerializer(serializers.Serializer):
    journey_id = serializers.UUIDField()
    specialty = serializers.CharField(allow_blank=True)
    faqs = CareCenterFAQSerializer(many=True)
    medications = CareCenterMedicationSerializer(many=True)
    guidance_links = serializers.ListField(child=serializers.URLField())


class UrgentMedicalRequestCreateSerializer(serializers.Serializer):
    question = serializers.CharField(min_length=5, max_length=4000)


class UrgentMedicalRequestReplySerializer(serializers.Serializer):
    answer = serializers.CharField(min_length=3, max_length=4000)


class UrgentMedicalRequestSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source="patient.full_name", read_only=True)
    patient_email = serializers.CharField(source="patient.email", read_only=True)
    patient_avatar_url = serializers.CharField(
        source="patient.avatar_url",
        read_only=True,
    )
    assigned_professional_name = serializers.CharField(
        source="assigned_professional.full_name",
        read_only=True,
    )
    answered_by_name = serializers.CharField(source="answered_by.full_name", read_only=True)

    class Meta:
        model = UrgentMedicalRequest
        fields = (
            "id",
            "status",
            "question",
            "answer",
            "patient_name",
            "patient_email",
            "patient_avatar_url",
            "assigned_professional",
            "assigned_professional_name",
            "answered_by",
            "answered_by_name",
            "answered_at",
            "created_at",
            "updated_at",
        )
        read_only_fields = fields
