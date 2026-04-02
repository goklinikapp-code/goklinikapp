from __future__ import annotations

from pathlib import Path

from rest_framework import serializers

from config.media_urls import AbsoluteMediaUrlsSerializerMixin
from config.media_urls import absolute_media_url

from .models import (
    EvolutionPhoto,
    PostOperatoryCheckin,
    PostOpChecklist,
    UrgentMedicalRequest,
    UrgentTicket,
)


ALLOWED_IMAGE_EXTENSIONS = {
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
    ".heic",
    ".heif",
    ".gif",
    ".bmp",
    ".tif",
    ".tiff",
}


def _validate_image_file(upload) -> None:
    content_type = str(getattr(upload, "content_type", "") or "").lower()
    name = str(getattr(upload, "name", "") or "").strip()
    extension = Path(name).suffix.lower()

    if content_type.startswith("image/"):
        return
    if extension in ALLOWED_IMAGE_EXTENSIONS:
        return

    raise serializers.ValidationError("Image file is required.")


class PostOpChecklistSerializer(serializers.ModelSerializer):
    day = serializers.IntegerField(source="day_number", read_only=True)
    title = serializers.CharField(source="item_text", read_only=True)
    completed = serializers.BooleanField(source="is_completed", read_only=True)

    class Meta:
        model = PostOpChecklist
        fields = (
            "id",
            "day_number",
            "item_text",
            "is_completed",
            "completed_at",
            "day",
            "title",
            "completed",
        )
        read_only_fields = fields


class EvolutionPhotoSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    day = serializers.IntegerField(source="day_number", read_only=True)
    image = serializers.CharField(source="photo_url", read_only=True)
    created_at = serializers.DateTimeField(source="uploaded_at", read_only=True)

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
            "day",
            "image",
            "created_at",
        )
        read_only_fields = fields


class EvolutionPhotoCreateSerializer(serializers.Serializer):
    journey_id = serializers.UUIDField()
    day_number = serializers.IntegerField(min_value=1)
    photo = serializers.FileField()
    is_anonymous = serializers.BooleanField(required=False, default=False)

    def validate_photo(self, value):
        _validate_image_file(value)
        return value


class PostOperatoryPhotoCreateSerializer(serializers.Serializer):
    journey_id = serializers.UUIDField(required=False)
    day = serializers.IntegerField(required=False, min_value=1)
    image = serializers.FileField(required=False)
    photo = serializers.FileField(required=False)
    is_anonymous = serializers.BooleanField(required=False, default=False)

    def validate(self, attrs):
        upload = attrs.get("image") or attrs.get("photo")
        if upload is None:
            raise serializers.ValidationError({"image": ["Image file is required."]})
        _validate_image_file(upload)
        attrs["image"] = upload
        return attrs


class JourneyAppointmentSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    appointment_type = serializers.CharField()
    appointment_date = serializers.DateField()
    appointment_time = serializers.TimeField()
    professional_name = serializers.CharField(allow_blank=True, allow_null=True)


class PostOperatoryCheckinSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostOperatoryCheckin
        fields = ("id", "journey", "day", "pain_level", "has_fever", "notes", "created_at")
        read_only_fields = fields


class PostOperatoryCheckinCreateSerializer(serializers.Serializer):
    journey_id = serializers.UUIDField(required=False)
    pain_level = serializers.IntegerField(min_value=0, max_value=10)
    has_fever = serializers.BooleanField(required=False, default=False)
    notes = serializers.CharField(required=False, allow_blank=True, allow_null=True)


class PostOperatoryChecklistUpdateSerializer(serializers.Serializer):
    completed = serializers.BooleanField()


class JourneyChecklistDaySerializer(serializers.Serializer):
    day_number = serializers.IntegerField()
    title = serializers.CharField()
    description = serializers.CharField()
    is_milestone = serializers.BooleanField()
    status = serializers.ChoiceField(choices=("completed", "today", "upcoming"))
    checklist_items = PostOpChecklistSerializer(many=True)


class MyJourneyResponseSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    clinic = serializers.UUIDField(allow_null=True, required=False)
    appointment = JourneyAppointmentSerializer(allow_null=True)
    specialty = serializers.DictField()
    surgery_date = serializers.DateField()
    start_date = serializers.DateField(allow_null=True, required=False)
    end_date = serializers.DateField(allow_null=True, required=False)
    total_days = serializers.IntegerField(required=False)
    current_day = serializers.IntegerField()
    status = serializers.CharField()
    protocol = JourneyChecklistDaySerializer(many=True)
    today_checklist = PostOpChecklistSerializer(many=True, required=False)
    checkin_submitted_today = serializers.BooleanField(required=False)
    today_checkin = PostOperatoryCheckinSerializer(required=False, allow_null=True)
    checkins = PostOperatoryCheckinSerializer(many=True, required=False)
    photos = EvolutionPhotoSerializer(many=True, required=False)
    history = serializers.ListField(child=serializers.DictField(), required=False)


class AdminJourneySerializer(serializers.Serializer):
    id = serializers.UUIDField()
    patient_id = serializers.UUIDField()
    patient_name = serializers.CharField()
    procedure = serializers.CharField(allow_blank=True)
    surgery_date = serializers.DateField()
    current_day = serializers.IntegerField()
    checklist_completion_percent = serializers.FloatField()


class PostOperatoryAdminListItemSerializer(serializers.Serializer):
    patient_name = serializers.CharField()
    patient_id = serializers.UUIDField()
    patient_avatar_url = serializers.CharField(required=False, allow_blank=True)
    status = serializers.CharField()
    current_day = serializers.IntegerField()
    total_days = serializers.IntegerField()
    last_checkin_date = serializers.DateTimeField(allow_null=True)
    last_pain_level = serializers.IntegerField(allow_null=True)
    has_alert = serializers.BooleanField()
    clinical_status = serializers.ChoiceField(choices=("ok", "delayed", "risk"))
    has_open_urgent_ticket = serializers.BooleanField(required=False)
    open_urgent_ticket_count = serializers.IntegerField(required=False)


class PostOperatoryChecklistByDaySerializer(serializers.Serializer):
    day = serializers.IntegerField()
    items = PostOpChecklistSerializer(many=True)


class PostOperatoryObservationSerializer(serializers.Serializer):
    day = serializers.IntegerField()
    notes = serializers.CharField()
    created_at = serializers.DateTimeField()


class PostOperatoryAdminDetailSerializer(serializers.Serializer):
    journey_id = serializers.UUIDField()
    patient_id = serializers.UUIDField()
    patient_name = serializers.CharField()
    patient_avatar_url = serializers.CharField(required=False, allow_blank=True)
    status = serializers.CharField()
    current_day = serializers.IntegerField()
    total_days = serializers.IntegerField()
    surgery_date = serializers.DateField()
    start_date = serializers.DateField(allow_null=True, required=False)
    end_date = serializers.DateField(allow_null=True, required=False)
    has_alert = serializers.BooleanField()
    clinical_status = serializers.ChoiceField(choices=("ok", "delayed", "risk"))
    days_without_checkin = serializers.IntegerField()
    last_checkin_date = serializers.DateTimeField(allow_null=True)
    last_pain_level = serializers.IntegerField(allow_null=True)
    checkins = PostOperatoryCheckinSerializer(many=True)
    checklist_by_day = PostOperatoryChecklistByDaySerializer(many=True)
    photos = EvolutionPhotoSerializer(many=True)
    observations = PostOperatoryObservationSerializer(many=True)
    has_open_urgent_ticket = serializers.BooleanField(required=False)
    urgent_tickets = serializers.ListField(child=serializers.DictField(), required=False)


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


class UrgentMedicalRequestSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
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


class UrgentTicketCreateSerializer(serializers.Serializer):
    message = serializers.CharField(min_length=5, max_length=4000)
    severity = serializers.ChoiceField(
        choices=UrgentTicket.SeverityChoices.choices,
        required=False,
        default=UrgentTicket.SeverityChoices.HIGH,
    )

    def validate_message(self, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("Message is required.")
        return cleaned


class UrgentTicketStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=(
            UrgentTicket.StatusChoices.VIEWED,
            UrgentTicket.StatusChoices.RESOLVED,
        )
    )


class UrgentTicketSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    patient_name = serializers.CharField(source="patient.full_name", read_only=True)
    doctor_name = serializers.CharField(source="doctor.full_name", read_only=True)
    images = serializers.SerializerMethodField()

    class Meta:
        model = UrgentTicket
        fields = (
            "id",
            "patient",
            "patient_name",
            "doctor",
            "doctor_name",
            "clinic",
            "post_op_journey",
            "message",
            "images",
            "severity",
            "status",
            "created_at",
            "updated_at",
        )
        read_only_fields = fields

    def get_images(self, obj: UrgentTicket) -> list[str]:
        request = self.context.get("request") if hasattr(self, "context") else None
        raw_images = obj.images if isinstance(obj.images, list) else []
        return [absolute_media_url(str(item), request=request) for item in raw_images if str(item).strip()]
