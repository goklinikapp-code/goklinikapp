from __future__ import annotations

import uuid
from datetime import date, timedelta

from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models import Q
from django.utils import timezone


def _default_postop_end_date() -> date:
    return timezone.localdate() + timedelta(days=89)


class PostOpProtocol(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    specialty = models.ForeignKey(
        "tenants.TenantSpecialty",
        on_delete=models.CASCADE,
        related_name="postop_protocols",
    )
    day_number = models.PositiveIntegerField()
    title = models.CharField(max_length=120)
    description = models.TextField()
    is_milestone = models.BooleanField(default=False)

    class Meta:
        db_table = "post_op_protocols"
        ordering = ["day_number", "title"]
        unique_together = ("specialty", "day_number", "title")

    def __str__(self) -> str:
        return f"{self.specialty.specialty_name} - day {self.day_number}"


class PostOpJourney(models.Model):
    class StatusChoices(models.TextChoices):
        ACTIVE = "active", "Active"
        COMPLETED = "completed", "Completed"
        CANCELLED = "cancelled", "Cancelled"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="postop_journeys",
    )
    clinic = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="postop_journeys",
        null=True,
        blank=True,
    )
    appointment = models.ForeignKey(
        "appointments.Appointment",
        on_delete=models.CASCADE,
        related_name="postop_journeys",
    )
    specialty = models.ForeignKey(
        "tenants.TenantSpecialty",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="postop_journeys",
    )
    surgery_date = models.DateField()
    start_date = models.DateField(
        null=True,
        blank=True,
    )
    end_date = models.DateField(
        null=True,
        blank=True,
    )
    current_day = models.PositiveIntegerField(default=1)
    status = models.CharField(
        max_length=20,
        choices=StatusChoices.choices,
        default=StatusChoices.ACTIVE,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "post_op_journeys"
        ordering = ["-surgery_date"]
        constraints = [
            models.UniqueConstraint(
                fields=["patient"],
                condition=Q(status="active"),
                name="post_op_unique_active_journey_by_patient",
            )
        ]

    @property
    def total_days(self) -> int:
        anchor = self.start_date or self.surgery_date
        finish = self.end_date or _default_postop_end_date()
        if finish < anchor:
            return 1
        return max((finish - anchor).days + 1, 1)

    def calculate_current_day(self, *, reference_date: date | None = None) -> int:
        anchor = self.start_date or self.surgery_date
        today = reference_date or timezone.localdate()
        raw_day = (today - anchor).days + 1
        return max(1, min(raw_day, self.total_days))

    def refresh_current_day(self, *, persist: bool = False) -> int:
        computed_day = self.calculate_current_day()
        if self.current_day != computed_day:
            self.current_day = computed_day
            if persist and self.pk:
                self.save(update_fields=["current_day", "updated_at"])
        return self.current_day

    def save(self, *args, **kwargs):
        if not self.start_date:
            self.start_date = self.surgery_date
        if not self.end_date:
            self.end_date = (self.start_date or self.surgery_date) + timedelta(days=89)

        if self.patient_id and not self.clinic_id:
            patient = getattr(self, "patient", None)
            tenant_id = getattr(patient, "tenant_id", None)
            if not tenant_id:
                from apps.patients.models import Patient

                tenant_id = (
                    Patient.objects.filter(id=self.patient_id)
                    .values_list("tenant_id", flat=True)
                    .first()
                )
            if tenant_id:
                self.clinic_id = tenant_id

        self.current_day = self.calculate_current_day()
        super().save(*args, **kwargs)

    def __str__(self) -> str:
        return f"Journey {self.patient.full_name} ({self.surgery_date})"


class PostOpChecklist(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    journey = models.ForeignKey(
        PostOpJourney,
        on_delete=models.CASCADE,
        related_name="checklist_items",
    )
    day_number = models.PositiveIntegerField()
    item_text = models.TextField()
    is_completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "post_op_checklist"
        ordering = ["day_number", "id"]

    def complete(self):
        self.is_completed = True
        self.completed_at = timezone.now()
        self.save(update_fields=["is_completed", "completed_at"])

    def __str__(self) -> str:
        return f"{self.journey_id} day {self.day_number}"


class PostOperatoryCheckin(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    journey = models.ForeignKey(
        PostOpJourney,
        on_delete=models.CASCADE,
        related_name="checkins",
    )
    day = models.PositiveIntegerField()
    pain_level = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(0), MaxValueValidator(10)],
    )
    has_fever = models.BooleanField(default=False)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "post_operatory_checkins"
        ordering = ["-day", "-created_at"]
        unique_together = ("journey", "day")
        indexes = [
            models.Index(fields=["journey", "day"]),
        ]

    def __str__(self) -> str:
        return f"Checkin {self.journey_id} day {self.day}"


class EvolutionPhoto(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    journey = models.ForeignKey(
        PostOpJourney,
        on_delete=models.CASCADE,
        related_name="photos",
    )
    day_number = models.PositiveIntegerField()
    photo_url = models.URLField()
    uploaded_at = models.DateTimeField(auto_now_add=True)
    is_visible_to_clinic = models.BooleanField(default=True)
    is_anonymous = models.BooleanField(default=False)

    class Meta:
        db_table = "post_op_evolution_photos"
        ordering = ["-uploaded_at"]

    def __str__(self) -> str:
        return f"Photo {self.journey_id} day {self.day_number}"


class UrgentMedicalRequest(models.Model):
    class StatusChoices(models.TextChoices):
        OPEN = "open", "Open"
        ANSWERED = "answered", "Answered"
        CLOSED = "closed", "Closed"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="urgent_medical_requests",
    )
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="urgent_medical_requests",
    )
    assigned_professional = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_urgent_medical_requests",
    )
    question = models.TextField()
    answer = models.TextField(blank=True)
    status = models.CharField(
        max_length=20,
        choices=StatusChoices.choices,
        default=StatusChoices.OPEN,
    )
    answered_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="answered_urgent_medical_requests",
    )
    answered_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "urgent_medical_requests"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["tenant", "status"]),
            models.Index(fields=["assigned_professional", "status"]),
            models.Index(fields=["patient", "created_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.patient_id}:{self.status}"


class UrgentTicket(models.Model):
    class SeverityChoices(models.TextChoices):
        LOW = "low", "Low"
        MEDIUM = "medium", "Medium"
        HIGH = "high", "High"

    class StatusChoices(models.TextChoices):
        OPEN = "open", "Open"
        VIEWED = "viewed", "Viewed"
        RESOLVED = "resolved", "Resolved"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="urgent_tickets",
    )
    doctor = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="urgent_tickets_as_doctor",
    )
    clinic = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="urgent_tickets",
    )
    post_op_journey = models.ForeignKey(
        PostOpJourney,
        on_delete=models.CASCADE,
        related_name="urgent_tickets",
    )
    message = models.TextField()
    images = models.JSONField(default=list, blank=True)
    severity = models.CharField(
        max_length=16,
        choices=SeverityChoices.choices,
        default=SeverityChoices.HIGH,
    )
    status = models.CharField(
        max_length=16,
        choices=StatusChoices.choices,
        default=StatusChoices.OPEN,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "urgent_tickets"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["clinic", "status"]),
            models.Index(fields=["doctor", "status"]),
            models.Index(fields=["patient", "created_at"]),
            models.Index(fields=["post_op_journey", "status"]),
        ]

    def __str__(self) -> str:
        return f"{self.patient_id}:{self.status}"
