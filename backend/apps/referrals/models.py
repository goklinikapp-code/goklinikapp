from __future__ import annotations

import uuid

from django.db import models


class Referral(models.Model):
    class StatusChoices(models.TextChoices):
        PENDING = "pending", "Pending"
        CONVERTED = "converted", "Converted"
        PAID = "paid", "Paid"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        related_name="referrals",
        on_delete=models.CASCADE,
    )
    referrer = models.ForeignKey(
        "users.GoKlinikUser",
        related_name="referrals_made",
        on_delete=models.CASCADE,
    )
    referred = models.ForeignKey(
        "users.GoKlinikUser",
        related_name="referral_received",
        on_delete=models.CASCADE,
    )
    status = models.CharField(
        max_length=20,
        choices=StatusChoices.choices,
        default=StatusChoices.PENDING,
    )
    commission_value = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
    )
    converted_at = models.DateTimeField(null=True, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "referrals"
        indexes = [
            models.Index(fields=["tenant", "status"]),
            models.Index(fields=["referrer", "status"]),
            models.Index(fields=["referred"]),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=["tenant", "referrer", "referred"],
                name="unique_referral_per_referrer_referred_per_tenant",
            )
        ]

    def __str__(self) -> str:
        return f"{self.referrer_id} -> {self.referred_id} ({self.status})"
