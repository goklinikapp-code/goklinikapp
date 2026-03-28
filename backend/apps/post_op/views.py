from __future__ import annotations

import uuid
from collections import defaultdict

from django.core.files.storage import default_storage
from django.db import models
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.appointments.models import Appointment
from apps.patients.models import DoctorPatientAssignment, Patient
from apps.users.models import GoKlinikUser

from .models import (
    EvolutionPhoto,
    PostOpChecklist,
    PostOpJourney,
    PostOpProtocol,
    UrgentMedicalRequest,
)
from .serializers import (
    AdminJourneySerializer,
    CareCenterResponseSerializer,
    EvolutionPhotoCreateSerializer,
    EvolutionPhotoSerializer,
    MyJourneyResponseSerializer,
    PostOpChecklistSerializer,
    UrgentMedicalRequestCreateSerializer,
    UrgentMedicalRequestReplySerializer,
    UrgentMedicalRequestSerializer,
)

STAFF_ROLES = {
    GoKlinikUser.RoleChoices.CLINIC_MASTER,
    GoKlinikUser.RoleChoices.SURGEON,
    GoKlinikUser.RoleChoices.NURSE,
}


def _appointment_payload(journey: PostOpJourney) -> dict:
    appointment = journey.appointment
    return {
        "id": appointment.id,
        "appointment_type": appointment.appointment_type,
        "appointment_date": appointment.appointment_date,
        "appointment_time": appointment.appointment_time,
        "professional_name": appointment.professional.full_name if appointment.professional else "",
    }


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
                "checklist_items": PostOpChecklistSerializer(day_items, many=True).data,
            }
        )
    return payload


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


class MyJourneyAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        journey = (
            PostOpJourney.objects.select_related("appointment", "specialty", "appointment__professional")
            .filter(
                patient_id=user.id,
                status=PostOpJourney.StatusChoices.ACTIVE,
            )
            .order_by("-surgery_date")
            .first()
        )
        if not journey:
            return Response(
                {"detail": "No active post-op journey found for this patient."},
                status=status.HTTP_404_NOT_FOUND,
            )

        specialty_payload = {
            "id": journey.specialty_id,
            "name": journey.specialty.specialty_name if journey.specialty else "",
        }
        response_data = {
            "id": journey.id,
            "appointment": _appointment_payload(journey),
            "specialty": specialty_payload,
            "surgery_date": journey.surgery_date,
            "current_day": journey.current_day,
            "status": journey.status,
            "protocol": _build_protocol_payload(journey),
        }

        serializer = MyJourneyResponseSerializer(response_data)
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
        filename = f"{uuid.uuid4()}_{upload.name}"
        storage_path = f"post_op_photos/{journey.id}/{filename}"
        stored_path = default_storage.save(storage_path, upload)
        photo_url = default_storage.url(stored_path)

        photo = EvolutionPhoto.objects.create(
            journey=journey,
            day_number=payload["day_number"],
            photo_url=photo_url,
            is_anonymous=payload.get("is_anonymous", False),
        )
        return Response(EvolutionPhotoSerializer(photo).data, status=status.HTTP_201_CREATED)


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
        return Response(EvolutionPhotoSerializer(queryset, many=True).data, status=status.HTTP_200_OK)


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
            return Response(UrgentMedicalRequestSerializer(queryset, many=True).data, status=status.HTTP_200_OK)

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
        return Response(UrgentMedicalRequestSerializer(queryset, many=True).data, status=status.HTTP_200_OK)

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
        return Response(
            UrgentMedicalRequestSerializer(urgent_request).data,
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

        return Response(UrgentMedicalRequestSerializer(urgent_request).data, status=status.HTTP_200_OK)
