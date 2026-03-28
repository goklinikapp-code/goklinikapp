from django.db import models
from django.utils import timezone

from apps.users.models import GoKlinikUser


class Patient(GoKlinikUser):
    class BloodTypeChoices(models.TextChoices):
        A_POS = "A+", "A+"
        A_NEG = "A-", "A-"
        B_POS = "B+", "B+"
        B_NEG = "B-", "B-"
        AB_POS = "AB+", "AB+"
        AB_NEG = "AB-", "AB-"
        O_POS = "O+", "O+"
        O_NEG = "O-", "O-"

    class ReferralSourceChoices(models.TextChoices):
        INSTAGRAM = "instagram", "Instagram"
        INDICATION = "indication", "Indication"
        GOOGLE = "google", "Google"
        OTHER = "other", "Other"

    class StatusChoices(models.TextChoices):
        ACTIVE = "active", "Active"
        INACTIVE = "inactive", "Inactive"
        LEAD = "lead", "Lead"

    blood_type = models.CharField(max_length=3, choices=BloodTypeChoices.choices, blank=True)
    allergies = models.TextField(blank=True)
    previous_surgeries = models.TextField(blank=True)
    current_medications = models.TextField(blank=True)
    emergency_contact_name = models.CharField(max_length=255, blank=True)
    emergency_contact_phone = models.CharField(max_length=30, blank=True)
    emergency_contact_relation = models.CharField(max_length=80, blank=True)
    health_insurance = models.CharField(max_length=120, blank=True)
    referral_source = models.CharField(
        max_length=20,
        choices=ReferralSourceChoices.choices,
        default=ReferralSourceChoices.OTHER,
    )
    status = models.CharField(
        max_length=20,
        choices=StatusChoices.choices,
        default=StatusChoices.LEAD,
    )
    specialty = models.ForeignKey(
        "tenants.TenantSpecialty",
        on_delete=models.SET_NULL,
        related_name="patients",
        null=True,
        blank=True,
    )
    notes = models.TextField(blank=True)

    class Meta:
        db_table = "patients"
        indexes = [
            models.Index(fields=["status"]),
        ]

    def save(self, *args, **kwargs):
        self.role = GoKlinikUser.RoleChoices.PATIENT
        super().save(*args, **kwargs)

    def __str__(self) -> str:
        return self.full_name


class DoctorPatientAssignment(models.Model):
    patient = models.OneToOneField(
        Patient,
        related_name="doctor_assignment",
        on_delete=models.CASCADE,
    )
    doctor = models.ForeignKey(
        GoKlinikUser,
        related_name="assigned_patients",
        on_delete=models.CASCADE,
        limit_choices_to={"role": GoKlinikUser.RoleChoices.SURGEON},
    )
    notes = models.TextField(blank=True)
    assigned_at = models.DateTimeField(default=timezone.now)
    assigned_by = models.ForeignKey(
        GoKlinikUser,
        related_name="doctor_assignments_made",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )

    class Meta:
        db_table = "doctor_patient_assignments"
        indexes = [
            models.Index(fields=["doctor"]),
            models.Index(fields=["assigned_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.patient_id} -> {self.doctor_id}"
