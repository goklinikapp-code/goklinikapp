from __future__ import annotations

import uuid
from datetime import time

from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone

from apps.users.models import GoKlinikUser


class Appointment(models.Model):
    class StatusChoices(models.TextChoices):
        PENDING = "pending", "Pending"
        CONFIRMED = "confirmed", "Confirmed"
        IN_PROGRESS = "in_progress", "In Progress"
        COMPLETED = "completed", "Completed"
        CANCELLED = "cancelled", "Cancelled"
        RESCHEDULED = "rescheduled", "Rescheduled"

    class AppointmentTypeChoices(models.TextChoices):
        FIRST_VISIT = "first_visit", "First Visit"
        RETURN = "return", "Return"
        SURGERY = "surgery", "Surgery"
        POST_OP_7D = "post_op_7d", "Post-op 7d"
        POST_OP_30D = "post_op_30d", "Post-op 30d"
        POST_OP_90D = "post_op_90d", "Post-op 90d"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="appointments",
    )
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="appointments",
    )
    professional = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.CASCADE,
        related_name="professional_appointments",
        null=True,
        blank=True,
    )
    specialty = models.ForeignKey(
        "tenants.TenantSpecialty",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="appointments",
    )
    appointment_date = models.DateField(default=timezone.localdate)
    appointment_time = models.TimeField(default=time(9, 0))
    duration_minutes = models.PositiveIntegerField(default=60)
    status = models.CharField(
        max_length=20,
        choices=StatusChoices.choices,
        default=StatusChoices.PENDING,
    )
    appointment_type = models.CharField(
        max_length=20,
        choices=AppointmentTypeChoices.choices,
        default=AppointmentTypeChoices.FIRST_VISIT,
    )
    clinic_location = models.CharField(max_length=255, blank=True)
    notes = models.TextField(blank=True)
    internal_notes = models.TextField(blank=True)
    cancellation_reason = models.TextField(blank=True)
    created_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_appointments",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "appointments"
        ordering = ["appointment_date", "appointment_time"]
        indexes = [
            models.Index(fields=["tenant", "appointment_date", "status"]),
            models.Index(fields=["professional", "appointment_date"]),
            models.Index(fields=["patient", "appointment_date"]),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=["tenant", "patient", "appointment_type"],
                condition=models.Q(
                    status__in=["pending", "confirmed", "in_progress"],
                ),
                name="uniq_active_patient_type_per_tenant",
            ),
            models.UniqueConstraint(
                fields=["tenant", "patient"],
                condition=models.Q(
                    status__in=["pending", "confirmed", "in_progress"],
                    appointment_type__in=["first_visit", "return", "surgery"],
                ),
                name="uniq_active_primary_flow_per_patient",
            ),
        ]

    def __str__(self) -> str:
        professional_name = self.professional.full_name if self.professional else "Unassigned"
        return (
            f"{self.patient.full_name} with {professional_name} "
            f"at {self.appointment_date} {self.appointment_time}"
        )

    @property
    def starts_at(self):
        from datetime import datetime

        return datetime.combine(self.appointment_date, self.appointment_time)

    @property
    def ends_at(self):
        from datetime import timedelta

        return self.starts_at + timedelta(minutes=self.duration_minutes)

    def clean(self):
        if self.professional and self.professional.role != GoKlinikUser.RoleChoices.SURGEON:
            raise ValidationError({"professional": "Professional must have surgeon role."})

        if self.professional and self.tenant_id and self.professional.tenant_id != self.tenant_id:
            raise ValidationError(
                {"professional": "Professional must belong to the same tenant."}
            )

        if self.patient and self.tenant_id and self.patient.tenant_id != self.tenant_id:
            raise ValidationError({"patient": "Patient must belong to the same tenant."})

        if self.specialty and self.tenant_id and self.specialty.tenant_id != self.tenant_id:
            raise ValidationError({"specialty": "Specialty must belong to the same tenant."})


class ProfessionalAvailability(models.Model):
    DAYS = (
        (0, "Monday"),
        (1, "Tuesday"),
        (2, "Wednesday"),
        (3, "Thursday"),
        (4, "Friday"),
        (5, "Saturday"),
        (6, "Sunday"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    professional = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.CASCADE,
        related_name="availabilities",
    )
    day_of_week = models.PositiveSmallIntegerField(choices=DAYS)
    start_time = models.TimeField()
    end_time = models.TimeField()
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "professional_availabilities"
        ordering = ["professional", "day_of_week", "start_time"]
        unique_together = ("professional", "day_of_week", "start_time", "end_time")

    def __str__(self) -> str:
        return f"{self.professional.full_name} - {self.get_day_of_week_display()}"


class BlockedPeriod(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    professional = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.CASCADE,
        related_name="blocked_periods",
    )
    start_datetime = models.DateTimeField()
    end_datetime = models.DateTimeField()
    reason = models.CharField(max_length=255)

    class Meta:
        db_table = "blocked_periods"
        ordering = ["-start_datetime"]

    def __str__(self) -> str:
        return f"{self.professional.full_name} blocked: {self.reason}"
