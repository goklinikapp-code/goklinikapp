from __future__ import annotations

import uuid

from django.db import models
from django.db.models import Q

from apps.users.models import GoKlinikUser


class PreOperatory(models.Model):
    class StatusChoices(models.TextChoices):
        PENDING = "pending", "Pending"
        IN_REVIEW = "in_review", "In review"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.CASCADE,
        related_name="pre_operatory_records",
        limit_choices_to={"role": GoKlinikUser.RoleChoices.PATIENT},
    )
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="pre_operatory_records",
    )
    allergies = models.TextField(blank=True)
    medications = models.TextField(blank=True)
    previous_surgeries = models.TextField(blank=True)
    diseases = models.TextField(blank=True)
    smoking = models.BooleanField(default=False)
    alcohol = models.BooleanField(default=False)
    height = models.FloatField(null=True, blank=True)
    weight = models.FloatField(null=True, blank=True)
    notes = models.TextField(blank=True)
    procedure = models.ForeignKey(
        "tenants.TenantSpecialty",
        on_delete=models.SET_NULL,
        related_name="pre_operatory_records",
        null=True,
        blank=True,
    )
    assigned_doctor = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        related_name="assigned_pre_operatory_records",
        null=True,
        blank=True,
        limit_choices_to={"role": GoKlinikUser.RoleChoices.SURGEON},
    )
    status = models.CharField(
        max_length=20,
        choices=StatusChoices.choices,
        default=StatusChoices.PENDING,
    )
    approved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "pre_operatory_records"
        ordering = ["-updated_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["patient"],
                condition=Q(
                    status__in=[
                        "pending",
                        "in_review",
                    ]
                ),
                name="pre_operatory_unique_active_by_patient",
            ),
        ]
        indexes = [
            models.Index(fields=["tenant", "status"]),
            models.Index(fields=["patient", "status"]),
        ]

    def __str__(self) -> str:
        return f"{self.patient_id}:{self.status}"


class PreOperatoryAuditLog(models.Model):
    class ActionChoices(models.TextChoices):
        CREATED = "created", "Created"
        PATIENT_UPDATED = "patient_updated", "Patient updated"
        CLINIC_UPDATED = "clinic_updated", "Clinic updated"
        FILE_DELETED = "file_deleted", "File deleted"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    pre_operatory = models.ForeignKey(
        PreOperatory,
        on_delete=models.CASCADE,
        related_name="audit_logs",
    )
    actor = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        related_name="pre_operatory_audit_logs",
        null=True,
        blank=True,
    )
    action = models.CharField(max_length=32, choices=ActionChoices.choices)
    details = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "pre_operatory_audit_logs"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["pre_operatory", "created_at"]),
            models.Index(fields=["action", "created_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.pre_operatory_id}:{self.action}"


class PreOperatoryFile(models.Model):
    class FileTypeChoices(models.TextChoices):
        PHOTO = "photo", "Photo"
        DOCUMENT = "document", "Document"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    pre_operatory = models.ForeignKey(
        PreOperatory,
        on_delete=models.CASCADE,
        related_name="files",
    )
    file_url = models.URLField(max_length=2048)
    type = models.CharField(max_length=20, choices=FileTypeChoices.choices)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "pre_operatory_files"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["pre_operatory", "type"]),
        ]

    def __str__(self) -> str:
        return f"{self.pre_operatory_id}:{self.type}"
