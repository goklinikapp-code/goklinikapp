from __future__ import annotations

import uuid

from django.db import models


class Transaction(models.Model):
    class TransactionTypeChoices(models.TextChoices):
        PROCEDURE = "procedure", "Procedure"
        PACKAGE = "package", "Package"
        INSTALLMENT = "installment", "Installment"

    class StatusChoices(models.TextChoices):
        PENDING = "pending", "Pending"
        PAID = "paid", "Paid"
        CANCELLED = "cancelled", "Cancelled"

    class PaymentMethodChoices(models.TextChoices):
        CREDIT_CARD = "credit_card", "Credit Card"
        BANK_TRANSFER = "bank_transfer", "Bank Transfer"
        PIX = "pix", "PIX"
        CASH = "cash", "Cash"
        INSTALLMENT = "installment", "Installment"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey("tenants.Tenant", on_delete=models.CASCADE, related_name="transactions")
    patient = models.ForeignKey("patients.Patient", on_delete=models.CASCADE, related_name="transactions")
    appointment = models.ForeignKey(
        "appointments.Appointment",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="transactions",
    )
    description = models.TextField()
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    transaction_type = models.CharField(max_length=20, choices=TransactionTypeChoices.choices)
    status = models.CharField(max_length=20, choices=StatusChoices.choices, default=StatusChoices.PENDING)
    due_date = models.DateField()
    paid_at = models.DateTimeField(null=True, blank=True)
    payment_method = models.CharField(max_length=20, choices=PaymentMethodChoices.choices)
    invoice_url = models.URLField(null=True, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "financial_transactions"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.patient.full_name} - {self.amount}"


class SessionPackage(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey("tenants.Tenant", on_delete=models.CASCADE, related_name="session_packages")
    patient = models.ForeignKey("patients.Patient", on_delete=models.CASCADE, related_name="session_packages")
    specialty = models.ForeignKey("tenants.TenantSpecialty", on_delete=models.SET_NULL, null=True, blank=True)
    total_sessions = models.PositiveIntegerField()
    used_sessions = models.PositiveIntegerField(default=0)
    package_name = models.CharField(max_length=120)
    total_amount = models.DecimalField(max_digits=12, decimal_places=2)
    purchase_date = models.DateField()

    class Meta:
        db_table = "session_packages"
        ordering = ["-purchase_date"]

    def __str__(self):
        return f"{self.package_name} - {self.patient.full_name}"
