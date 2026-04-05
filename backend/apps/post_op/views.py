from __future__ import annotations

import logging
import uuid
from collections import defaultdict
from datetime import timedelta
from pathlib import Path

from django.conf import settings
from django.core.files.storage import FileSystemStorage
from django.core.files.storage import default_storage
from django.db import models
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from config.media_urls import absolute_media_url

from apps.appointments.models import Appointment
from apps.patients.models import DoctorPatientAssignment, Patient
from apps.users.models import GoKlinikUser

from .models import (
    EvolutionPhoto,
    PostOperatoryCheckin,
    PostOpChecklist,
    PostOpJourney,
    PostOpProtocol,
    UrgentMedicalRequest,
    UrgentTicket,
)
from .serializers import (
    AdminJourneySerializer,
    CareCenterResponseSerializer,
    EvolutionPhotoCreateSerializer,
    EvolutionPhotoSerializer,
    MyJourneyResponseSerializer,
    PostOperatoryAdminDetailSerializer,
    PostOperatoryAdminListItemSerializer,
    PostOperatoryCheckinCreateSerializer,
    PostOperatoryCheckinSerializer,
    PostOperatoryChecklistUpdateSerializer,
    PostOperatoryPhotoCreateSerializer,
    PostOpChecklistSerializer,
    UrgentMedicalRequestCreateSerializer,
    UrgentMedicalRequestReplySerializer,
    UrgentMedicalRequestSerializer,
    UrgentTicketCreateSerializer,
    UrgentTicketSerializer,
    UrgentTicketStatusUpdateSerializer,
)

STAFF_ROLES = {
    GoKlinikUser.RoleChoices.CLINIC_MASTER,
    GoKlinikUser.RoleChoices.SURGEON,
    GoKlinikUser.RoleChoices.NURSE,
}
URGENT_TICKET_DUPLICATE_WINDOW = timedelta(minutes=5)
ALLOWED_URGENT_IMAGE_EXTENSIONS = {
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
logger = logging.getLogger(__name__)


def _is_clinic_admin(user: GoKlinikUser) -> bool:
    return user.role == GoKlinikUser.RoleChoices.CLINIC_MASTER


def _can_view_postop_panel(user: GoKlinikUser) -> bool:
    return user.role in {
        GoKlinikUser.RoleChoices.CLINIC_MASTER,
        GoKlinikUser.RoleChoices.SURGEON,
    }


def _days_without_checkin(
    *,
    journey: PostOpJourney,
    last_checkin: PostOperatoryCheckin | None,
) -> int:
    if not last_checkin:
        return max(journey.current_day, 0)
    return max(journey.current_day - last_checkin.day, 0)


def _build_alert_state(
    *,
    journey: PostOpJourney,
    last_checkin: PostOperatoryCheckin | None,
) -> dict:
    days_without = _days_without_checkin(journey=journey, last_checkin=last_checkin)
    pain_alert = bool(last_checkin and last_checkin.pain_level >= 8)
    fever_alert = bool(last_checkin and last_checkin.has_fever)
    has_checkin_today = bool(last_checkin and last_checkin.day >= journey.current_day)
    missing_checkin_today = not has_checkin_today

    if pain_alert or fever_alert:
        clinical_status = "risk"
    elif missing_checkin_today:
        clinical_status = "delayed"
    else:
        clinical_status = "ok"

    has_alert = clinical_status == "risk"

    return {
        "has_alert": has_alert,
        "clinical_status": clinical_status,
        "days_without_checkin": days_without,
    }


def _appointment_payload(journey: PostOpJourney) -> dict | None:
    appointment = journey.appointment
    if not appointment:
        return None
    return {
        "id": appointment.id,
        "appointment_type": appointment.appointment_type,
        "appointment_date": appointment.appointment_date,
        "appointment_time": appointment.appointment_time,
        "professional_name": appointment.professional.full_name if appointment.professional else "",
    }


def _refresh_journey_current_day(journey: PostOpJourney, *, persist: bool = False) -> int:
    prefetched_checkins = getattr(journey, "_prefetched_objects_cache", {}).get("checkins")
    if prefetched_checkins is None:
        first_checkin = (
            PostOperatoryCheckin.objects.filter(journey_id=journey.id)
            .order_by("day", "created_at")
            .first()
        )
    else:
        first_checkin = min(
            prefetched_checkins,
            key=lambda item: (item.day, item.created_at),
            default=None,
        )

    fields_to_update: list[str] = []
    if first_checkin:
        base_start = journey.start_date or journey.surgery_date
        inferred_start = timezone.localdate(first_checkin.created_at) - timedelta(
            days=max(first_checkin.day - 1, 0),
        )
        if inferred_start < base_start:
            duration_days = max((journey.end_date - base_start).days, 0) if journey.end_date else 89
            journey.start_date = inferred_start
            fields_to_update.append("start_date")
            if journey.end_date:
                journey.end_date = inferred_start + timedelta(days=duration_days)
                fields_to_update.append("end_date")

    current_day = journey.calculate_current_day()
    if journey.current_day != current_day:
        journey.current_day = current_day
        fields_to_update.append("current_day")
        if persist:
            update_fields = list(dict.fromkeys([*fields_to_update, "updated_at"]))
            journey.save(update_fields=update_fields)
    elif persist and fields_to_update:
        update_fields = list(dict.fromkeys([*fields_to_update, "updated_at"]))
        journey.save(update_fields=update_fields)
    return journey.current_day


def _active_journey_for_patient(patient_id: str) -> PostOpJourney | None:
    journey = (
        PostOpJourney.objects.select_related(
            "appointment",
            "specialty",
            "appointment__professional",
            "patient",
        )
        .prefetch_related("checklist_items", "checkins", "photos")
        .filter(
            patient_id=patient_id,
            status=PostOpJourney.StatusChoices.ACTIVE,
            appointment__status=Appointment.StatusChoices.COMPLETED,
            appointment__appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
        )
        .order_by("-surgery_date")
        .first()
    )
    if journey:
        _refresh_journey_current_day(journey, persist=True)
    return journey


def _resolve_patient_journey_for_write(
    *,
    user: GoKlinikUser,
    journey_id: str | None = None,
) -> PostOpJourney | None:
    if journey_id:
        journey = (
            PostOpJourney.objects.select_related("patient")
            .filter(
                id=journey_id,
                patient_id=user.id,
                status=PostOpJourney.StatusChoices.ACTIVE,
            )
            .first()
        )
    else:
        journey = _active_journey_for_patient(str(user.id))

    if journey:
        _refresh_journey_current_day(journey, persist=True)
    return journey


def _build_protocol_payload(journey: PostOpJourney) -> list[dict]:
    protocols = PostOpProtocol.objects.filter(specialty_id=journey.specialty_id).order_by("day_number", "id")
    checklist = PostOpChecklist.objects.filter(journey=journey).order_by("day_number", "id")

    checklist_by_day: dict[int, list[PostOpChecklist]] = defaultdict(list)
    for item in checklist:
        checklist_by_day[item.day_number].append(item)

    current_day = journey.current_day
    payload: list[dict] = []
    for protocol in protocols:
        day_items = checklist_by_day.get(protocol.day_number, [])
        all_completed = bool(day_items) and all(item.is_completed for item in day_items)

        if all_completed:
            day_status = "completed"
        elif protocol.day_number <= current_day:
            day_status = "today"
        else:
            day_status = "upcoming"

        payload.append(
            {
                "day_number": protocol.day_number,
                "title": protocol.title,
                "description": protocol.description,
                "is_milestone": protocol.is_milestone,
                "status": day_status,
                "checklist_items": day_items,
            }
        )
    return payload


def _build_history_payload(
    *,
    journey: PostOpJourney,
    checklist_items: list[PostOpChecklist],
    checkins: list[PostOperatoryCheckin],
) -> list[dict]:
    checklist_by_day: dict[int, list[PostOpChecklist]] = defaultdict(list)
    for item in checklist_items:
        checklist_by_day[item.day_number].append(item)

    checkin_by_day: dict[int, PostOperatoryCheckin] = {}
    for checkin in checkins:
        checkin_by_day.setdefault(checkin.day, checkin)

    history: list[dict] = []
    current_day = journey.current_day
    for day in range(1, current_day + 1):
        checkin = checkin_by_day.get(day)
        day_checklist = checklist_by_day.get(day, [])
        completed = bool(day_checklist) and all(item.is_completed for item in day_checklist)

        if checkin:
            state = "enviado"
        elif completed:
            state = "ok"
        elif day < current_day:
            state = "pendente"
        else:
            state = "hoje"

        history.append(
            {
                "day": day,
                "title": f"Dia {day}",
                "status": state,
                "has_checkin": checkin is not None,
                "checklist_completed": completed,
            }
        )

    return history


def _resolve_professional_for_urgent_request(patient) -> GoKlinikUser | None:
    assignment = DoctorPatientAssignment.objects.select_related("doctor").filter(patient_id=patient.id).first()
    if assignment and assignment.doctor and assignment.doctor.is_active:
        return assignment.doctor

    nearest_appointment = (
        Appointment.objects.select_related("professional")
        .filter(
            patient_id=patient.id,
            professional__isnull=False,
        )
        .exclude(status=Appointment.StatusChoices.CANCELLED)
        .order_by("-appointment_date", "-appointment_time")
        .first()
    )
    if nearest_appointment and nearest_appointment.professional and nearest_appointment.professional.is_active:
        return nearest_appointment.professional

    return (
        GoKlinikUser.objects.filter(
            tenant_id=patient.tenant_id,
            role=GoKlinikUser.RoleChoices.SURGEON,
            is_active=True,
        )
        .order_by("first_name", "last_name", "email")
        .first()
    )


def _resolve_urgent_request_recipients(urgent_request: UrgentMedicalRequest) -> list[GoKlinikUser]:
    recipients: dict[str, GoKlinikUser] = {}
    patient_id = urgent_request.patient_id

    assigned = urgent_request.assigned_professional
    if assigned and assigned.is_active and assigned.id != patient_id:
        recipients[str(assigned.id)] = assigned

    clinic_masters = GoKlinikUser.objects.filter(
        tenant_id=urgent_request.tenant_id,
        role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        is_active=True,
    ).exclude(id=patient_id)
    for clinic_master in clinic_masters:
        recipients[str(clinic_master.id)] = clinic_master

    return list(recipients.values())


def _urgent_request_preview(question: str) -> str:
    raw = " ".join((question or "").strip().split())
    if not raw:
        return "Nova mensagem."
    if len(raw) > 140:
        return f"{raw[:137]}..."
    return raw


def _notify_urgent_request_created(urgent_request: UrgentMedicalRequest) -> None:
    from apps.notifications.services import NotificationService

    recipients = _resolve_urgent_request_recipients(urgent_request)
    if not recipients:
        return

    sender_name = urgent_request.patient.full_name
    preview = _urgent_request_preview(urgent_request.question)
    request_id = str(urgent_request.id)

    for recipient in recipients:
        title = f"Nova mensagem de {sender_name}"
        body = f"{sender_name}: {preview}"
        payload = {
            "event": "urgent_request_created",
            "urgent_request_id": request_id,
            "sender_id": str(urgent_request.patient_id),
            "sender_role": GoKlinikUser.RoleChoices.PATIENT,
        }

        try:
            NotificationService.send_push_to_user(
                user=recipient,
                title=title,
                body=body,
                data_extra=payload,
                event_code="urgent_request_created",
                segment="post_op_urgent_request",
                idempotency_key=f"urgent_request_created:{request_id}:{recipient.id}",
                notification_type="new_message",
                related_object_id=urgent_request.id,
                create_in_app_notification=False,
            )
        except Exception:  # noqa: BLE001
            logger.exception(
                "Unable to send urgent-request push request=%s recipient=%s",
                request_id,
                recipient.id,
            )

        try:
            NotificationService.create_in_app_notification(
                recipient=recipient,
                title=title,
                body=body,
                notification_type="new_message",
                related_object_id=urgent_request.id,
            )
        except Exception:  # noqa: BLE001
            logger.exception(
                "Unable to persist urgent-request in-app notification request=%s recipient=%s",
                request_id,
                recipient.id,
            )


def _notify_urgent_request_answered(urgent_request: UrgentMedicalRequest) -> None:
    from apps.notifications.services import NotificationService

    patient = urgent_request.patient
    if not patient or not patient.is_active:
        return

    responder_name = (
        urgent_request.answered_by.full_name
        if urgent_request.answered_by
        else "Equipe da clínica"
    )
    answer = _urgent_request_preview(urgent_request.answer or "")
    request_id = str(urgent_request.id)
    title = "Resposta da clínica"
    body = f"{responder_name}: {answer}"
    payload = {
        "event": "urgent_request_answered",
        "urgent_request_id": request_id,
        "responder_id": str(urgent_request.answered_by_id or ""),
    }

    try:
        NotificationService.send_push_to_user(
            user=patient,
            title=title,
            body=body,
            data_extra=payload,
            event_code="urgent_request_answered",
            segment="post_op_urgent_request",
            idempotency_key=f"urgent_request_answered:{request_id}:{patient.id}",
            notification_type="new_message",
            related_object_id=urgent_request.id,
            create_in_app_notification=False,
        )
    except Exception:  # noqa: BLE001
        logger.exception(
            "Unable to send urgent-request reply push request=%s recipient=%s",
            request_id,
            patient.id,
        )

    try:
        NotificationService.create_in_app_notification(
            recipient=patient,
            title=title,
            body=body,
            notification_type="new_message",
            related_object_id=urgent_request.id,
        )
    except Exception:  # noqa: BLE001
        logger.exception(
            "Unable to persist urgent-request reply in-app notification request=%s recipient=%s",
            request_id,
            patient.id,
        )


def _save_postop_upload(*, upload, journey_id, request) -> str:
    safe_name = Path(getattr(upload, "name", "") or "upload.bin").name
    filename = f"{uuid.uuid4()}_{safe_name}"
    storage_path = f"post_op_photos/{journey_id}/{filename}"

    try:
        stored_path = default_storage.save(storage_path, upload)
        file_url = default_storage.url(stored_path)
    except Exception:
        media_root = Path(getattr(settings, "MEDIA_ROOT", Path.cwd()))
        base_url = getattr(settings, "MEDIA_URL", "/media/")
        fallback_storage = FileSystemStorage(
            location=str(media_root),
            base_url=base_url,
        )
        if hasattr(upload, "seek"):
            upload.seek(0)
        stored_path = fallback_storage.save(storage_path, upload)
        file_url = fallback_storage.url(stored_path)

    return absolute_media_url(file_url, request=request)


def _validate_urgent_ticket_upload(upload) -> None:
    content_type = str(getattr(upload, "content_type", "") or "").lower()
    name = str(getattr(upload, "name", "") or "").strip()
    extension = Path(name).suffix.lower()

    if content_type.startswith("image/"):
        return
    if extension in ALLOWED_URGENT_IMAGE_EXTENSIONS:
        return

    raise ValueError("Image file is required.")


def _extract_urgent_ticket_uploads(request) -> list:
    uploads = []

    direct = request.FILES.get("image")
    if direct is not None:
        uploads.append(direct)

    uploads.extend(request.FILES.getlist("images"))

    deduped = []
    seen = set()
    for upload in uploads:
        upload_id = id(upload)
        if upload_id in seen:
            continue
        seen.add(upload_id)
        deduped.append(upload)
    return deduped


def _resolve_doctor_for_urgent_ticket(*, patient: Patient, journey: PostOpJourney) -> GoKlinikUser | None:
    assignment = (
        DoctorPatientAssignment.objects.select_related("doctor")
        .filter(patient_id=patient.id)
        .first()
    )
    if assignment and assignment.doctor and assignment.doctor.is_active:
        return assignment.doctor

    professional = getattr(journey.appointment, "professional", None)
    if (
        professional
        and professional.role == GoKlinikUser.RoleChoices.SURGEON
        and professional.is_active
    ):
        return professional

    return None


class MyJourneyAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        journey = _active_journey_for_patient(str(user.id))
        if not journey:
            return Response(
                {"detail": "No active post-op journey found for this patient."},
                status=status.HTTP_404_NOT_FOUND,
            )

        checklist = list(
            PostOpChecklist.objects.filter(journey=journey).order_by("day_number", "id"),
        )
        checkins = list(
            PostOperatoryCheckin.objects.filter(journey=journey).order_by("-day", "-created_at"),
        )
        photos = list(
            EvolutionPhoto.objects.filter(journey=journey).order_by("-uploaded_at"),
        )

        today_checklist = [item for item in checklist if item.day_number == journey.current_day]
        today_checkin = next((item for item in checkins if item.day == journey.current_day), None)

        specialty_payload = {
            "id": journey.specialty_id,
            "name": journey.specialty.specialty_name if journey.specialty else "",
        }
        response_data = {
            "id": journey.id,
            "clinic": journey.clinic_id,
            "appointment": _appointment_payload(journey),
            "specialty": specialty_payload,
            "surgery_date": journey.surgery_date,
            "start_date": journey.start_date,
            "end_date": journey.end_date,
            "total_days": journey.total_days,
            "current_day": journey.current_day,
            "status": journey.status,
            "protocol": _build_protocol_payload(journey),
            "today_checklist": today_checklist,
            "checkin_submitted_today": today_checkin is not None,
            "today_checkin": today_checkin,
            "checkins": checkins,
            "photos": photos,
            "history": _build_history_payload(
                journey=journey,
                checklist_items=checklist,
                checkins=checkins,
            ),
        }

        serializer = MyJourneyResponseSerializer(response_data, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class CompleteChecklistItemAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, checklist_id):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        item = (
            PostOpChecklist.objects.select_related("journey__patient")
            .filter(id=checklist_id)
            .first()
        )
        if not item:
            return Response({"detail": "Checklist item not found."}, status=status.HTTP_404_NOT_FOUND)

        if str(item.journey.patient_id) != str(user.id):
            return Response(status=status.HTTP_403_FORBIDDEN)

        if not item.is_completed:
            item.is_completed = True
            item.completed_at = timezone.now()
            item.save(update_fields=["is_completed", "completed_at"])

        return Response(PostOpChecklistSerializer(item).data, status=status.HTTP_200_OK)


class PostOperatoryChecklistUpdateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, checklist_id):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        item = (
            PostOpChecklist.objects.select_related("journey")
            .filter(id=checklist_id, journey__patient_id=user.id)
            .first()
        )
        if not item:
            return Response({"detail": "Checklist item not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = PostOperatoryChecklistUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        completed = serializer.validated_data["completed"]
        item.is_completed = completed
        item.completed_at = timezone.now() if completed else None
        item.save(update_fields=["is_completed", "completed_at"])

        return Response(PostOpChecklistSerializer(item).data, status=status.HTTP_200_OK)


class PostOperatoryCheckinCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = PostOperatoryCheckinCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = serializer.validated_data

        journey = _resolve_patient_journey_for_write(
            user=user,
            journey_id=str(payload.get("journey_id")) if payload.get("journey_id") else None,
        )
        if not journey:
            return Response({"detail": "Active journey not found."}, status=status.HTTP_404_NOT_FOUND)

        start_date = journey.start_date or journey.surgery_date
        if start_date and timezone.localdate() < start_date:
            return Response(
                {"detail": "Check-in is only available from the journey start date."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        day = journey.current_day
        checkin, created = PostOperatoryCheckin.objects.get_or_create(
            journey=journey,
            day=day,
            defaults={
                "pain_level": payload["pain_level"],
                "has_fever": payload.get("has_fever", False),
                "notes": (payload.get("notes") or "").strip(),
            },
        )

        if not created:
            return Response(
                {"detail": "Check-in for today has already been submitted."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            PostOperatoryCheckinSerializer(checkin).data,
            status=status.HTTP_201_CREATED,
        )


class EvolutionPhotoCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = EvolutionPhotoCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = serializer.validated_data

        journey = (
            PostOpJourney.objects.select_related("patient")
            .filter(id=payload["journey_id"])
            .first()
        )
        if not journey:
            return Response({"detail": "Journey not found."}, status=status.HTTP_404_NOT_FOUND)

        user = request.user
        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            if str(journey.patient_id) != str(user.id):
                return Response(status=status.HTTP_403_FORBIDDEN)
        elif user.role in STAFF_ROLES:
            if journey.patient.tenant_id != user.tenant_id:
                return Response(status=status.HTTP_403_FORBIDDEN)
        else:
            return Response(status=status.HTTP_403_FORBIDDEN)

        upload = payload["photo"]
        photo_url = _save_postop_upload(
            upload=upload,
            journey_id=journey.id,
            request=request,
        )

        photo = EvolutionPhoto.objects.create(
            journey=journey,
            day_number=payload["day_number"],
            photo_url=photo_url,
            is_anonymous=payload.get("is_anonymous", False),
        )
        return Response(
            EvolutionPhotoSerializer(photo, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class PostOperatoryPhotoCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = PostOperatoryPhotoCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = serializer.validated_data

        journey = _resolve_patient_journey_for_write(
            user=user,
            journey_id=str(payload.get("journey_id")) if payload.get("journey_id") else None,
        )
        if not journey:
            return Response({"detail": "Active journey not found."}, status=status.HTTP_404_NOT_FOUND)

        day_number = payload.get("day") or journey.current_day
        upload = payload["image"]

        photo_url = _save_postop_upload(
            upload=upload,
            journey_id=journey.id,
            request=request,
        )

        photo = EvolutionPhoto.objects.create(
            journey=journey,
            day_number=day_number,
            photo_url=photo_url,
            is_anonymous=payload.get("is_anonymous", False),
        )
        return Response(
            EvolutionPhotoSerializer(photo, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class EvolutionPhotoListAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, journey_id):
        journey = PostOpJourney.objects.select_related("patient").filter(id=journey_id).first()
        if not journey:
            return Response({"detail": "Journey not found."}, status=status.HTTP_404_NOT_FOUND)

        user = request.user
        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            if str(journey.patient_id) != str(user.id):
                return Response(status=status.HTTP_403_FORBIDDEN)
        elif user.role in STAFF_ROLES:
            if journey.patient.tenant_id != user.tenant_id:
                return Response(status=status.HTTP_403_FORBIDDEN)
        else:
            return Response(status=status.HTTP_403_FORBIDDEN)

        queryset = EvolutionPhoto.objects.filter(journey_id=journey_id).order_by("-uploaded_at")
        return Response(
            EvolutionPhotoSerializer(
                queryset,
                many=True,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )


class PostOperatoryAdminListAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if not _can_view_postop_panel(user):
            return Response(status=status.HTTP_403_FORBIDDEN)
        if not user.tenant_id:
            return Response(
                {"detail": "Clinic tenant not found."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        status_filter = (request.query_params.get("status") or "").strip()
        valid_statuses = set(PostOpJourney.StatusChoices.values)
        if status_filter and status_filter not in valid_statuses:
            return Response(
                {"status": ["Invalid status value."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        queryset = (
            PostOpJourney.objects.select_related("patient")
            .prefetch_related("checkins")
            .filter(patient__tenant_id=user.tenant_id)
            .filter(
                appointment__status=Appointment.StatusChoices.COMPLETED,
                appointment__appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            )
            .order_by("patient_id", "-surgery_date", "-created_at")
        )
        if user.role == GoKlinikUser.RoleChoices.SURGEON:
            queryset = queryset.filter(
                models.Q(patient__doctor_assignment__doctor_id=user.id)
                | models.Q(appointment__professional_id=user.id)
            ).distinct()
        if status_filter:
            queryset = queryset.filter(status=status_filter)

        journey_ids = list(queryset.values_list("id", flat=True))
        open_ticket_counts_by_patient: dict[str, int] = {}
        if journey_ids:
            open_counts = (
                UrgentTicket.objects.filter(
                    post_op_journey_id__in=journey_ids,
                    status=UrgentTicket.StatusChoices.OPEN,
                )
                .values("patient_id")
                .annotate(total=models.Count("id"))
            )
            open_ticket_counts_by_patient = {
                str(item["patient_id"]): int(item["total"])
                for item in open_counts
            }

        seen_patients: set[str] = set()
        items: list[dict] = []

        for journey in queryset:
            patient_key = str(journey.patient_id)
            if patient_key in seen_patients:
                continue
            seen_patients.add(patient_key)

            if journey.status == PostOpJourney.StatusChoices.ACTIVE:
                _refresh_journey_current_day(journey, persist=True)

            last_checkin = (
                PostOperatoryCheckin.objects.filter(journey_id=journey.id)
                .order_by("-day", "-created_at")
                .first()
            )
            alert_state = _build_alert_state(journey=journey, last_checkin=last_checkin)
            open_ticket_count = open_ticket_counts_by_patient.get(patient_key, 0)

            items.append(
                {
                    "patient_name": journey.patient.full_name,
                    "patient_id": journey.patient_id,
                    "patient_avatar_url": absolute_media_url(
                        journey.patient.avatar_url,
                        request=request,
                    ),
                    "status": journey.status,
                    "current_day": journey.current_day,
                    "total_days": journey.total_days,
                    "last_checkin_date": last_checkin.created_at if last_checkin else None,
                    "last_pain_level": last_checkin.pain_level if last_checkin else None,
                    "has_alert": alert_state["has_alert"],
                    "clinical_status": alert_state["clinical_status"],
                    "has_open_urgent_ticket": open_ticket_count > 0,
                    "open_urgent_ticket_count": open_ticket_count,
                }
            )

        serializer = PostOperatoryAdminListItemSerializer(items, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class PostOperatoryAdminDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, patient_id):
        user = request.user
        if not _can_view_postop_panel(user):
            return Response(status=status.HTTP_403_FORBIDDEN)
        if not user.tenant_id:
            return Response(
                {"detail": "Clinic tenant not found."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        queryset = (
            PostOpJourney.objects.select_related("patient")
            .prefetch_related("checklist_items", "checkins", "photos")
            .filter(
                patient_id=patient_id,
                patient__tenant_id=user.tenant_id,
            )
            .filter(
                appointment__status=Appointment.StatusChoices.COMPLETED,
                appointment__appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            )
            .order_by("-surgery_date", "-created_at")
        )
        if user.role == GoKlinikUser.RoleChoices.SURGEON:
            queryset = queryset.filter(
                models.Q(patient__doctor_assignment__doctor_id=user.id)
                | models.Q(appointment__professional_id=user.id)
            ).distinct()

        journey = queryset.first()
        if not journey:
            return Response(
                {"detail": "Post-operatory journey not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if journey.status == PostOpJourney.StatusChoices.ACTIVE:
            _refresh_journey_current_day(journey, persist=True)

        checkins = list(
            PostOperatoryCheckin.objects.filter(journey_id=journey.id).order_by("-day", "-created_at"),
        )
        checklist = list(
            PostOpChecklist.objects.filter(journey_id=journey.id).order_by("day_number", "id"),
        )
        photos = list(
            EvolutionPhoto.objects.filter(journey_id=journey.id).order_by("-uploaded_at"),
        )
        urgent_tickets = list(
            UrgentTicket.objects.select_related("patient", "doctor")
            .filter(post_op_journey_id=journey.id)
            .order_by("-created_at")
        )

        checklist_by_day_map: dict[int, list[PostOpChecklist]] = defaultdict(list)
        for item in checklist:
            checklist_by_day_map[item.day_number].append(item)

        checklist_by_day = [
            {"day": day, "items": items}
            for day, items in sorted(checklist_by_day_map.items(), key=lambda pair: pair[0])
        ]

        observations = [
            {
                "day": item.day,
                "notes": (item.notes or "").strip(),
                "created_at": item.created_at,
            }
            for item in checkins
            if (item.notes or "").strip()
        ]

        last_checkin = checkins[0] if checkins else None
        alert_state = _build_alert_state(journey=journey, last_checkin=last_checkin)
        open_urgent_ticket_count = sum(
            1 for item in urgent_tickets if item.status == UrgentTicket.StatusChoices.OPEN
        )

        payload = {
            "journey_id": journey.id,
            "patient_id": journey.patient_id,
            "patient_name": journey.patient.full_name,
            "patient_avatar_url": absolute_media_url(
                journey.patient.avatar_url,
                request=request,
            ),
            "status": journey.status,
            "current_day": journey.current_day,
            "total_days": journey.total_days,
            "surgery_date": journey.surgery_date,
            "start_date": journey.start_date,
            "end_date": journey.end_date,
            "has_alert": alert_state["has_alert"],
            "clinical_status": alert_state["clinical_status"],
            "days_without_checkin": alert_state["days_without_checkin"],
            "last_checkin_date": last_checkin.created_at if last_checkin else None,
            "last_pain_level": last_checkin.pain_level if last_checkin else None,
            "checkins": checkins,
            "checklist_by_day": checklist_by_day,
            "photos": photos,
            "observations": observations,
            "has_open_urgent_ticket": open_urgent_ticket_count > 0,
            "urgent_tickets": UrgentTicketSerializer(
                urgent_tickets,
                many=True,
                context={"request": request},
            ).data,
        }
        serializer = PostOperatoryAdminDetailSerializer(
            payload,
            context={"request": request},
        )
        return Response(serializer.data, status=status.HTTP_200_OK)


class AdminJourneysAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role not in STAFF_ROLES:
            return Response(status=status.HTTP_403_FORBIDDEN)

        journeys = (
            PostOpJourney.objects.select_related("patient", "appointment", "specialty")
            .filter(
                status=PostOpJourney.StatusChoices.ACTIVE,
                patient__tenant_id=user.tenant_id,
                appointment__status=Appointment.StatusChoices.COMPLETED,
                appointment__appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            )
            .order_by("-surgery_date")
        )

        response_items: list[dict] = []
        for journey in journeys:
            total_items = journey.checklist_items.count()
            completed_items = journey.checklist_items.filter(is_completed=True).count()
            completion = round((completed_items / total_items) * 100, 2) if total_items else 0.0

            procedure = ""
            if journey.specialty:
                procedure = journey.specialty.specialty_name
            elif journey.appointment:
                procedure = journey.appointment.get_appointment_type_display()

            response_items.append(
                {
                    "id": journey.id,
                    "patient_id": journey.patient_id,
                    "patient_name": journey.patient.full_name,
                    "procedure": procedure,
                    "surgery_date": journey.surgery_date,
                    "current_day": journey.current_day,
                    "checklist_completion_percent": completion,
                }
            )

        serializer = AdminJourneySerializer(response_items, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class CareCenterAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, journey_id):
        journey = PostOpJourney.objects.select_related("patient", "specialty").filter(id=journey_id).first()
        if not journey:
            return Response({"detail": "Journey not found."}, status=status.HTTP_404_NOT_FOUND)

        user = request.user
        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            if str(journey.patient_id) != str(user.id):
                return Response(status=status.HTTP_403_FORBIDDEN)
        elif user.role in STAFF_ROLES:
            if journey.patient.tenant_id != user.tenant_id:
                return Response(status=status.HTTP_403_FORBIDDEN)
        else:
            return Response(status=status.HTTP_403_FORBIDDEN)

        data = {
            "journey_id": journey.id,
            "specialty": journey.specialty.specialty_name if journey.specialty else "",
            "faqs": [
                {
                    "question": "Quando posso dirigir?",
                    "answer": "Em geral, após liberação médica na consulta de retorno.",
                },
                {
                    "question": "Quais sinais de alerta devo observar?",
                    "answer": "Dor intensa persistente, febre e sangramento ativo devem ser avaliados.",
                },
                {
                    "question": "Há restrições alimentares?",
                    "answer": "Priorize dieta leve e siga as orientações médicas específicas.",
                },
            ],
            "medications": [
                {
                    "name": "Analgésico",
                    "dosage": "500mg",
                    "schedule": "A cada 8h por 5 dias",
                },
                {
                    "name": "Antibiótico",
                    "dosage": "Conforme prescrição",
                    "schedule": "Siga a receita do cirurgião",
                },
            ],
            "guidance_links": [
                "https://goklinik.com/guides/atividade-fisica",
                "https://goklinik.com/guides/higiene",
            ],
        }
        serializer = CareCenterResponseSerializer(data)
        return Response(serializer.data, status=status.HTTP_200_OK)


class UrgentTicketListCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        queryset = UrgentTicket.objects.select_related(
            "patient",
            "doctor",
            "post_op_journey",
        )

        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            queryset = queryset.filter(patient_id=user.id)
        elif user.role == GoKlinikUser.RoleChoices.CLINIC_MASTER:
            if not user.tenant_id:
                return Response(
                    {"detail": "Clinic tenant not found."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            queryset = queryset.filter(clinic_id=user.tenant_id)
        elif user.role == GoKlinikUser.RoleChoices.SURGEON:
            if not user.tenant_id:
                return Response(
                    {"detail": "Clinic tenant not found."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            queryset = queryset.filter(clinic_id=user.tenant_id, doctor_id=user.id)
        else:
            return Response(status=status.HTTP_403_FORBIDDEN)

        return Response(
            UrgentTicketSerializer(
                queryset.order_by("-created_at"),
                many=True,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )

    def post(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        patient = Patient.objects.select_related("tenant").filter(id=user.id).first()
        if not patient or not patient.tenant_id:
            return Response(
                {"detail": "Patient tenant not found."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        journey = _active_journey_for_patient(str(patient.id))
        if not journey:
            return Response(
                {"detail": "Active post-op journey is required to open an urgent ticket."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        payload_serializer = UrgentTicketCreateSerializer(data=request.data)
        payload_serializer.is_valid(raise_exception=True)

        doctor = _resolve_doctor_for_urgent_ticket(patient=patient, journey=journey)
        if not doctor:
            return Response(
                {"detail": "Assigned doctor not found for this patient."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        duplicate_cutoff = timezone.now() - URGENT_TICKET_DUPLICATE_WINDOW
        has_duplicate = UrgentTicket.objects.filter(
            patient_id=patient.id,
            post_op_journey_id=journey.id,
            status=UrgentTicket.StatusChoices.OPEN,
            created_at__gte=duplicate_cutoff,
        ).exists()
        if has_duplicate:
            return Response(
                {"detail": "Já existe um ticket urgente aberto criado recentemente."},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        uploads = _extract_urgent_ticket_uploads(request)
        image_urls: list[str] = []
        for upload in uploads:
            try:
                _validate_urgent_ticket_upload(upload)
            except ValueError as exc:
                return Response({"images": [str(exc)]}, status=status.HTTP_400_BAD_REQUEST)

            image_urls.append(
                _save_postop_upload(
                    upload=upload,
                    journey_id=journey.id,
                    request=request,
                )
            )

        ticket = UrgentTicket.objects.create(
            patient_id=patient.id,
            doctor_id=doctor.id,
            clinic_id=patient.tenant_id,
            post_op_journey_id=journey.id,
            message=payload_serializer.validated_data["message"],
            images=image_urls,
            severity=payload_serializer.validated_data.get(
                "severity",
                UrgentTicket.SeverityChoices.HIGH,
            ),
            status=UrgentTicket.StatusChoices.OPEN,
        )

        return Response(
            UrgentTicketSerializer(ticket, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class UrgentTicketStatusUpdateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, ticket_id):
        user = request.user
        if user.role not in {
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
            GoKlinikUser.RoleChoices.SURGEON,
        }:
            return Response(status=status.HTTP_403_FORBIDDEN)
        if not user.tenant_id:
            return Response(
                {"detail": "Clinic tenant not found."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        ticket = (
            UrgentTicket.objects.select_related("doctor")
            .filter(id=ticket_id, clinic_id=user.tenant_id)
            .first()
        )
        if not ticket:
            return Response({"detail": "Urgent ticket not found."}, status=status.HTTP_404_NOT_FOUND)

        if (
            user.role == GoKlinikUser.RoleChoices.SURGEON
            and ticket.doctor_id
            and ticket.doctor_id != user.id
        ):
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = UrgentTicketStatusUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        ticket.status = serializer.validated_data["status"]
        update_fields = ["status", "updated_at"]

        if user.role == GoKlinikUser.RoleChoices.SURGEON and not ticket.doctor_id:
            ticket.doctor_id = user.id
            update_fields.append("doctor")

        ticket.save(update_fields=update_fields)

        return Response(
            UrgentTicketSerializer(ticket, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )


class UrgentMedicalRequestListCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user

        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            queryset = UrgentMedicalRequest.objects.filter(patient_id=user.id).select_related(
                "assigned_professional",
                "answered_by",
                "patient",
            )
            return Response(
                UrgentMedicalRequestSerializer(
                    queryset,
                    many=True,
                    context={"request": request},
                ).data,
                status=status.HTTP_200_OK,
            )

        if user.role not in STAFF_ROLES:
            return Response(status=status.HTTP_403_FORBIDDEN)

        queryset = UrgentMedicalRequest.objects.filter(tenant_id=user.tenant_id).select_related(
            "assigned_professional",
            "answered_by",
            "patient",
        )
        if user.role == GoKlinikUser.RoleChoices.SURGEON:
            queryset = queryset.filter(
                models.Q(assigned_professional_id=user.id)
                | models.Q(assigned_professional__isnull=True)
            )
        return Response(
            UrgentMedicalRequestSerializer(
                queryset,
                many=True,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )

    def post(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        patient = Patient.objects.select_related("tenant").filter(id=user.id).first()
        if not patient or not patient.tenant_id:
            return Response({"detail": "Patient tenant not found."}, status=status.HTTP_400_BAD_REQUEST)

        serializer = UrgentMedicalRequestCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        assigned_professional = _resolve_professional_for_urgent_request(patient)

        urgent_request = UrgentMedicalRequest.objects.create(
            tenant_id=patient.tenant_id,
            patient_id=patient.id,
            assigned_professional=assigned_professional,
            question=serializer.validated_data["question"].strip(),
            status=UrgentMedicalRequest.StatusChoices.OPEN,
        )
        _notify_urgent_request_created(urgent_request)
        return Response(
            UrgentMedicalRequestSerializer(
                urgent_request,
                context={"request": request},
            ).data,
            status=status.HTTP_201_CREATED,
        )


class UrgentMedicalRequestReplyAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, request_id):
        user = request.user
        if user.role not in STAFF_ROLES:
            return Response(status=status.HTTP_403_FORBIDDEN)

        urgent_request = (
            UrgentMedicalRequest.objects.select_related("assigned_professional")
            .filter(id=request_id, tenant_id=user.tenant_id)
            .first()
        )
        if not urgent_request:
            return Response({"detail": "Urgent request not found."}, status=status.HTTP_404_NOT_FOUND)

        if (
            user.role == GoKlinikUser.RoleChoices.SURGEON
            and urgent_request.assigned_professional_id
            and urgent_request.assigned_professional_id != user.id
        ):
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = UrgentMedicalRequestReplySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        if not urgent_request.assigned_professional_id:
            urgent_request.assigned_professional_id = user.id

        urgent_request.answer = serializer.validated_data["answer"].strip()
        urgent_request.status = UrgentMedicalRequest.StatusChoices.ANSWERED
        urgent_request.answered_by_id = user.id
        urgent_request.answered_at = timezone.now()
        urgent_request.save(
            update_fields=[
                "assigned_professional",
                "answer",
                "status",
                "answered_by",
                "answered_at",
                "updated_at",
            ]
        )
        _notify_urgent_request_answered(urgent_request)

        return Response(
            UrgentMedicalRequestSerializer(
                urgent_request,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )
