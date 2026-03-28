from __future__ import annotations

import uuid
from datetime import date

from django.db import models
from django.utils import timezone


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

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="postop_journeys",
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

    @property
    def current_day(self) -> int:
        delta = timezone.localdate() - self.surgery_date
        return max(delta.days + 1, 1)

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
