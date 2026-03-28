from __future__ import annotations

from datetime import datetime

from django.db.models import Q
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from django.utils import timezone

from apps.appointments.models import Appointment
from apps.chat.models import Message
from apps.users.models import GoKlinikUser

from .models import DoctorPatientAssignment, Patient
from .permissions import CanManagePatients
from .serializers import (
    AssignDoctorSerializer,
    PatientCreateUpdateSerializer,
    PatientDetailSerializer,
    PatientListSerializer,
)


class PatientPagination(PageNumberPagination):
    page_size = 25


class PatientViewSet(viewsets.ModelViewSet):
    permission_classes = [CanManagePatients]
    pagination_class = PatientPagination

    def get_queryset(self):
        queryset = Patient.objects.select_related(
            "tenant",
            "specialty",
            "doctor_assignment",
            "doctor_assignment__doctor",
            "doctor_assignment__assigned_by",
        ).all()
        user = self.request.user
        if not getattr(user, "is_authenticated", False) or not hasattr(user, "role"):
            return queryset.none()

        if user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            queryset = queryset.filter(tenant_id=user.tenant_id)

        status_filter = self.request.query_params.get("status")
        specialty_filter = self.request.query_params.get("specialty")
        created_from = self.request.query_params.get("created_from")
        created_to = self.request.query_params.get("created_to")

        if status_filter:
            queryset = queryset.filter(status=status_filter)

        if specialty_filter:
            queryset = queryset.filter(specialty_id=specialty_filter)

        if created_from:
            queryset = queryset.filter(date_joined__date__gte=created_from)

        if created_to:
            queryset = queryset.filter(date_joined__date__lte=created_to)

        return queryset.order_by("-date_joined")

    def get_serializer_class(self):
        if self.action == "list":
            return PatientListSerializer
        if self.action in {"create", "update", "partial_update"}:
            return PatientCreateUpdateSerializer
        return PatientDetailSerializer

    def perform_create(self, serializer):
        serializer.save()

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)

        detail_serializer = PatientDetailSerializer(
            serializer.instance,
            context=self.get_serializer_context(),
        )
        headers = self.get_success_headers(detail_serializer.data)
        return Response(detail_serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop("partial", False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        serializer.save()

        detail_serializer = PatientDetailSerializer(
            serializer.instance,
            context=self.get_serializer_context(),
        )
        return Response(detail_serializer.data, status=status.HTTP_200_OK)

    def partial_update(self, request, *args, **kwargs):
        kwargs["partial"] = True
        return self.update(request, *args, **kwargs)

    @action(detail=False, methods=["get"], url_path="my-patients")
    def my_patients(self, request):
        user = request.user
        if user.role not in {
            GoKlinikUser.RoleChoices.SURGEON,
            GoKlinikUser.RoleChoices.NURSE,
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
        }:
            return Response(status=status.HTTP_403_FORBIDDEN)

        queryset = self.get_queryset()
        if user.role == GoKlinikUser.RoleChoices.SURGEON:
            queryset = queryset.filter(
                Q(doctor_assignment__doctor_id=user.id)
                | Q(
                    appointments__professional_id=user.id,
                    appointments__status__in=[
                        Appointment.StatusChoices.PENDING,
                        Appointment.StatusChoices.CONFIRMED,
                        Appointment.StatusChoices.IN_PROGRESS,
                        Appointment.StatusChoices.RESCHEDULED,
                    ],
                )
            ).distinct()
        elif user.role == GoKlinikUser.RoleChoices.NURSE:
            queryset = queryset.filter(doctor_assignment__isnull=False)
        else:
            professional_id = request.query_params.get("professional_id")
            if professional_id:
                queryset = queryset.filter(doctor_assignment__doctor_id=professional_id)
            else:
                queryset = queryset.filter(doctor_assignment__isnull=False)

        page = self.paginate_queryset(queryset)
        serializer = PatientListSerializer(
            page if page is not None else queryset,
            many=True,
            context=self.get_serializer_context(),
        )
        if page is not None:
            return self.get_paginated_response(serializer.data)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["get"], url_path="timeline")
    def timeline(self, request, pk=None):
        patient = self.get_object()

        items: list[dict] = []

        appointments = Appointment.objects.filter(patient=patient).order_by(
            "appointment_date", "appointment_time"
        )
        interactions = Message.objects.filter(room__patient=patient).order_by("created_at")

        for event in appointments:
            timestamp = datetime.combine(event.appointment_date, event.appointment_time)
            items.append(
                {
                    "timestamp": timestamp,
                    "type": "appointment",
                    "title": event.get_appointment_type_display(),
                    "description": event.notes,
                    "status": event.status,
                }
            )

        for event in interactions:
            items.append(
                {
                    "timestamp": event.created_at,
                    "type": "interaction",
                    "title": event.get_message_type_display(),
                    "description": event.content,
                    "status": "logged",
                }
            )

        items.sort(key=lambda item: item["timestamp"] or datetime.min)

        return Response(items, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"], url_path="assign-doctor")
    def assign_doctor(self, request, pk=None):
        user = request.user
        if user.role not in {
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
            GoKlinikUser.RoleChoices.SECRETARY,
        }:
            return Response(status=status.HTTP_403_FORBIDDEN)

        patient = self.get_object()
        serializer = AssignDoctorSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        doctor = (
            GoKlinikUser.objects.filter(
                id=serializer.validated_data["doctor_id"],
                tenant_id=patient.tenant_id,
                role=GoKlinikUser.RoleChoices.SURGEON,
                is_active=True,
            )
            .order_by("id")
            .first()
        )
        if not doctor:
            return Response(
                {"doctor_id": ["Doctor not found for this tenant."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        DoctorPatientAssignment.objects.update_or_create(
            patient=patient,
            defaults={
                "doctor": doctor,
                "notes": serializer.validated_data.get("notes", "").strip(),
                "assigned_at": timezone.now(),
                "assigned_by": user,
            },
        )

        updated_patient = self.get_queryset().filter(pk=patient.pk).first()
        payload = PatientDetailSerializer(
            updated_patient or patient,
            context=self.get_serializer_context(),
        ).data
        return Response(payload, status=status.HTTP_200_OK)
