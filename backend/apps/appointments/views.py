from __future__ import annotations

from datetime import datetime
import logging
import uuid

from django.db import transaction
from django.utils.dateparse import parse_date
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import APIException, PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from config.media_urls import absolute_media_url

from apps.notifications.tasks import (
    dispatch_appointment_created_workflows_task,
    schedule_appointment_reminder_workflows_task,
    schedule_postop_followup_workflows_task,
)
from apps.notifications.services import NotificationService
from apps.patients.models import DoctorPatientAssignment
from apps.users.models import GoKlinikUser

from .models import Appointment
from .serializers import (
    AppointmentCancelSerializer,
    AppointmentSerializer,
    AppointmentStatusUpdateSerializer,
)
from .services import AppointmentService
from .tasks import create_postop_schedule

logger = logging.getLogger(__name__)

APPOINTMENT_STATUS_LABELS_PT_BR = {
    Appointment.StatusChoices.PENDING: "pendente",
    Appointment.StatusChoices.CONFIRMED: "confirmado",
    Appointment.StatusChoices.IN_PROGRESS: "em andamento",
    Appointment.StatusChoices.COMPLETED: "concluído",
    Appointment.StatusChoices.CANCELLED: "cancelado",
    Appointment.StatusChoices.RESCHEDULED: "reagendado",
}


class AppointmentConflictException(APIException):
    status_code = status.HTTP_409_CONFLICT
    default_detail = (
        "Este horário acabou de ser ocupado. Escolha outro horário disponível."
    )
    default_code = "appointment_conflict"


class AppointmentViewSet(viewsets.ModelViewSet):
    serializer_class = AppointmentSerializer
    permission_classes = [IsAuthenticated]

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        if request.user.role == GoKlinikUser.RoleChoices.SUPER_ADMIN:
            raise PermissionDenied("SaaS owner cannot access clinic appointment operations.")

    def get_queryset(self):
        queryset = Appointment.objects.select_related(
            "tenant", "patient", "professional", "specialty", "created_by"
        )
        user = self.request.user
        if not getattr(user, "is_authenticated", False) or not hasattr(user, "role"):
            return queryset.none()

        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            queryset = queryset.filter(patient_id=user.id)
        elif user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            queryset = queryset.filter(tenant_id=user.tenant_id)

        professional = (
            self.request.query_params.get("professional")
            or self.request.query_params.get("professional_id")
        )
        status_filter = self.request.query_params.get("status")
        patient = self.request.query_params.get("patient")
        date_from = self.request.query_params.get("date_from")
        date_to = self.request.query_params.get("date_to")

        # Surgeons should only see their own appointments in the mobile app,
        # regardless of the query params provided by the client.
        if user.role == GoKlinikUser.RoleChoices.SURGEON:
            queryset = queryset.filter(professional_id=user.id)
        elif professional:
            queryset = queryset.filter(professional_id=professional)
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        if patient:
            queryset = queryset.filter(patient_id=patient)
        if date_from:
            queryset = queryset.filter(appointment_date__gte=date_from)
        if date_to:
            queryset = queryset.filter(appointment_date__lte=date_to)

        return queryset.order_by("appointment_date", "appointment_time")

    def perform_create(self, serializer):
        user = self.request.user
        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            raise PermissionDenied("Patients can only view appointments.")
        if user.role not in {
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
            GoKlinikUser.RoleChoices.SECRETARY,
            GoKlinikUser.RoleChoices.NURSE,
            GoKlinikUser.RoleChoices.SURGEON,
        }:
            raise PermissionDenied("Role not allowed to create appointments.")
        professional = serializer.validated_data.get("professional")
        appointment_date = serializer.validated_data.get("appointment_date")
        appointment_time = serializer.validated_data.get("appointment_time")
        duration_minutes = serializer.validated_data.get("duration_minutes", 60)

        with transaction.atomic():
            if professional and appointment_date and appointment_time:
                # Serialize booking attempts for the same professional to avoid
                # race conditions creating duplicate slots.
                GoKlinikUser.objects.select_for_update().filter(id=professional.id).first()
                conflict = AppointmentService.get_conflicting_appointment(
                    professional_id=professional.id,
                    appointment_date=appointment_date,
                    appointment_time=appointment_time,
                    duration_minutes=duration_minutes,
                )
                if conflict:
                    raise AppointmentConflictException()

            appointment = serializer.save(created_by=self.request.user)

        # Keep surgeon -> patient linkage in sync with new bookings so
        # "my patients" views can include scheduled patients consistently.
        professional = appointment.professional
        if (
            appointment.patient_id
            and professional
            and professional.role == GoKlinikUser.RoleChoices.SURGEON
        ):
            DoctorPatientAssignment.objects.update_or_create(
                patient=appointment.patient,
                defaults={
                    "doctor": professional,
                    "assigned_at": timezone.now(),
                    "assigned_by": user,
                },
            )

        self._dispatch_creation_side_effects(appointment=appointment)
        self._notify_admin_appointment_created(appointment=appointment)

    def perform_update(self, serializer):
        user = self.request.user
        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            raise PermissionDenied("Patients can only view appointments.")
        if user.role not in {
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
            GoKlinikUser.RoleChoices.SECRETARY,
            GoKlinikUser.RoleChoices.NURSE,
            GoKlinikUser.RoleChoices.SURGEON,
        }:
            raise PermissionDenied("Role not allowed to update appointments.")

        appointment = self.get_object()
        old_status = appointment.status
        old_date = appointment.appointment_date
        old_time = appointment.appointment_time
        old_professional_id = appointment.professional_id
        professional = serializer.validated_data.get(
            "professional", appointment.professional
        )
        appointment_date = serializer.validated_data.get(
            "appointment_date", appointment.appointment_date
        )
        appointment_time = serializer.validated_data.get(
            "appointment_time", appointment.appointment_time
        )
        duration_minutes = serializer.validated_data.get(
            "duration_minutes", appointment.duration_minutes
        )

        with transaction.atomic():
            if professional and appointment_date and appointment_time:
                GoKlinikUser.objects.select_for_update().filter(id=professional.id).first()
                conflict = AppointmentService.get_conflicting_appointment(
                    professional_id=professional.id,
                    appointment_date=appointment_date,
                    appointment_time=appointment_time,
                    duration_minutes=duration_minutes,
                    exclude_appointment_id=appointment.id,
                )
                if conflict:
                    raise AppointmentConflictException()

            updated = serializer.save()

        if (
            updated.patient_id
            and updated.professional
            and updated.professional.role == GoKlinikUser.RoleChoices.SURGEON
        ):
            DoctorPatientAssignment.objects.update_or_create(
                patient=updated.patient,
                defaults={
                    "doctor": updated.professional,
                    "assigned_at": timezone.now(),
                    "assigned_by": user,
                },
            )

        self._dispatch_status_side_effects(
            appointment=updated,
            old_status=old_status,
        )
        if (
            old_date != updated.appointment_date
            or old_time != updated.appointment_time
            or old_professional_id != updated.professional_id
        ):
            self._notify_admin_appointment_rescheduled(
                appointment=updated,
                old_date=old_date,
                old_time=old_time,
            )
        if old_status != updated.status:
            self._notify_admin_appointment_status_changed(
                appointment=updated,
                old_status=old_status,
            )

    @action(detail=False, methods=["get"], url_path="available-slots")
    def available_slots(self, request):
        professional_id = request.query_params.get("professional_id")
        date_str = request.query_params.get("date")
        specialty_id = request.query_params.get("specialty_id")
        appointment_id = request.query_params.get("appointment_id")
        if specialty_id:
            try:
                uuid.UUID(str(specialty_id))
            except ValueError:
                specialty_id = None
        if appointment_id:
            try:
                uuid.UUID(str(appointment_id))
            except ValueError:
                appointment_id = None

        if not professional_id or not date_str:
            return Response(
                {"detail": "professional_id and date are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        date = parse_date(date_str)
        if not date:
            return Response(
                {"detail": "Invalid date format. Use YYYY-MM-DD."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        slots = AppointmentService.get_available_slots(
            professional_id,
            date,
            specialty_id,
            appointment_id,
        )
        return Response(
            {
                "professional_id": professional_id,
                "date": date_str,
                "specialty_id": specialty_id,
                "appointment_id": appointment_id,
                "slots": slots,
            }
        )

    @action(detail=True, methods=["put"], url_path="status")
    def update_status(self, request, pk=None):
        appointment = self.get_object()
        if request.user.role == GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = AppointmentStatusUpdateSerializer(
            data=request.data,
            context={"appointment": appointment},
        )
        serializer.is_valid(raise_exception=True)

        old_status = appointment.status
        appointment.status = serializer.validated_data["status"]

        if "internal_notes" in serializer.validated_data:
            notes = serializer.validated_data["internal_notes"]
            if notes:
                appointment.internal_notes = notes

        appointment.save(update_fields=["status", "internal_notes", "updated_at"])

        self._dispatch_status_side_effects(
            appointment=appointment,
            old_status=old_status,
        )
        if old_status != appointment.status:
            self._notify_admin_appointment_status_changed(
                appointment=appointment,
                old_status=old_status,
            )

        return Response(
            AppointmentSerializer(appointment, context={"request": request}).data
        )

    def destroy(self, request, *args, **kwargs):
        if request.user.role == GoKlinikUser.RoleChoices.PATIENT:
            raise PermissionDenied("Patients can only view appointments.")
        appointment = self.get_object()
        serializer = AppointmentCancelSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        appointment.status = Appointment.StatusChoices.CANCELLED
        appointment.cancellation_reason = serializer.validated_data["reason"]
        appointment.save(update_fields=["status", "cancellation_reason", "updated_at"])

        return Response(status=status.HTTP_204_NO_CONTENT)

    def _dispatch_status_side_effects(
        self,
        *,
        appointment: Appointment,
        old_status: str,
    ) -> None:
        if (
            old_status != Appointment.StatusChoices.CONFIRMED
            and appointment.status == Appointment.StatusChoices.CONFIRMED
        ):
            try:
                dispatch_appointment_created_workflows_task.delay(str(appointment.id))
            except Exception as exc:  # noqa: BLE001
                logger.warning("Unable to dispatch appointment confirmation for %s: %s", appointment.id, exc)

        if (
            old_status != Appointment.StatusChoices.CONFIRMED
            and appointment.status == Appointment.StatusChoices.CONFIRMED
        ):
            try:
                schedule_appointment_reminder_workflows_task.delay(str(appointment.id))
            except Exception as exc:  # noqa: BLE001
                logger.warning("Unable to dispatch reminder task for %s: %s", appointment.id, exc)

        if (
            appointment.appointment_type == Appointment.AppointmentTypeChoices.SURGERY
            and old_status != Appointment.StatusChoices.COMPLETED
            and appointment.status == Appointment.StatusChoices.COMPLETED
        ):
            try:
                # Keep this synchronous to guarantee immediate consistency across
                # admin, doctor and patient experiences right after completion.
                create_postop_schedule(str(appointment.id))
                schedule_postop_followup_workflows_task.delay(str(appointment.id))
            except Exception as exc:  # noqa: BLE001
                logger.warning("Unable to create post-op schedule for %s: %s", appointment.id, exc)

    def _dispatch_creation_side_effects(
        self,
        *,
        appointment: Appointment,
    ) -> None:
        try:
            dispatch_appointment_created_workflows_task.delay(str(appointment.id))
        except Exception as exc:  # noqa: BLE001
            logger.warning("Unable to dispatch appointment confirmation for %s: %s", appointment.id, exc)

        if appointment.status == Appointment.StatusChoices.CONFIRMED:
            try:
                schedule_appointment_reminder_workflows_task.delay(str(appointment.id))
            except Exception as exc:  # noqa: BLE001
                logger.warning("Unable to dispatch reminder task for %s: %s", appointment.id, exc)

        if (
            appointment.appointment_type == Appointment.AppointmentTypeChoices.SURGERY
            and appointment.status == Appointment.StatusChoices.COMPLETED
        ):
            try:
                create_postop_schedule(str(appointment.id))
                schedule_postop_followup_workflows_task.delay(str(appointment.id))
            except Exception as exc:  # noqa: BLE001
                logger.warning("Unable to create post-op schedule for %s: %s", appointment.id, exc)

    def _appointment_when(self, *, date, when_time) -> str:
        return f"{date.strftime('%d/%m/%Y')} às {when_time.strftime('%H:%M')}"

    def _appointment_procedure_label(self, appointment: Appointment) -> str:
        if appointment.specialty:
            return appointment.specialty.specialty_name
        return appointment.get_appointment_type_display()

    def _status_label(self, status_code: str) -> str:
        return APPOINTMENT_STATUS_LABELS_PT_BR.get(status_code, status_code)

    def _notify_admin_appointment_created(self, *, appointment: Appointment) -> None:
        procedure = self._appointment_procedure_label(appointment)
        when_label = self._appointment_when(
            date=appointment.appointment_date,
            when_time=appointment.appointment_time,
        )
        actor_name = self.request.user.full_name
        title = "Novo agendamento criado"
        body = (
            f"{appointment.patient.full_name} • {procedure} em {when_label}. "
            f"Criado por {actor_name}."
        )
        NotificationService.notify_clinic_masters_in_app(
            tenant_id=appointment.tenant_id,
            title=title,
            body=body,
            related_object_id=appointment.id,
        )

    def _notify_admin_appointment_rescheduled(
        self,
        *,
        appointment: Appointment,
        old_date,
        old_time,
    ) -> None:
        old_when = self._appointment_when(date=old_date, when_time=old_time)
        new_when = self._appointment_when(
            date=appointment.appointment_date,
            when_time=appointment.appointment_time,
        )
        actor_name = self.request.user.full_name
        title = "Agendamento remarcado"
        body = (
            f"{appointment.patient.full_name}: de {old_when} para {new_when}. "
            f"Alterado por {actor_name}."
        )
        NotificationService.notify_clinic_masters_in_app(
            tenant_id=appointment.tenant_id,
            title=title,
            body=body,
            related_object_id=appointment.id,
        )

    def _notify_admin_appointment_status_changed(
        self,
        *,
        appointment: Appointment,
        old_status: str,
    ) -> None:
        actor_name = self.request.user.full_name
        title = "Status de agendamento atualizado"
        body = (
            f"{appointment.patient.full_name}: {self._status_label(old_status)} → "
            f"{self._status_label(appointment.status)}. Atualizado por {actor_name}."
        )
        NotificationService.notify_clinic_masters_in_app(
            tenant_id=appointment.tenant_id,
            title=title,
            body=body,
            related_object_id=appointment.id,
        )

    @action(detail=False, methods=["get"], url_path="available-professionals")
    def available_professionals(self, request):
        user = request.user
        queryset = GoKlinikUser.objects.filter(
            role=GoKlinikUser.RoleChoices.SURGEON,
            is_active=True,
        )

        if user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            queryset = queryset.filter(tenant_id=user.tenant_id)

        assigned_doctor_id = None
        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            assigned_doctor_id = (
                DoctorPatientAssignment.objects.filter(patient_id=user.id)
                .values_list("doctor_id", flat=True)
                .first()
            )
            if assigned_doctor_id:
                queryset = queryset.filter(id=assigned_doctor_id)
            else:
                queryset = queryset.filter(is_visible_in_app=True)
        else:
            queryset = queryset.filter(is_visible_in_app=True)

        professionals = queryset.order_by("first_name", "last_name", "email")
        payload = [
            {
                "id": str(item.id),
                "name": item.full_name,
                "email": item.email,
                "avatar_url": absolute_media_url(item.avatar_url, request=request),
                "is_assigned": bool(assigned_doctor_id and str(item.id) == str(assigned_doctor_id)),
            }
            for item in professionals
        ]
        return Response({"results": payload}, status=status.HTTP_200_OK)
