from __future__ import annotations

import uuid

from django.db import models


class TravelPlan(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="travel_plans",
    )
    patient = models.OneToOneField(
        "users.GoKlinikUser",
        on_delete=models.CASCADE,
        related_name="travel_plan",
        limit_choices_to={"role": "patient"},
    )
    passport_number = models.CharField(max_length=50, blank=True)
    created_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_travel_plans",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "travel_plans"
        indexes = [
            models.Index(fields=["tenant", "patient"]),
            models.Index(fields=["created_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.patient.full_name} ({self.tenant_id})"


class FlightInfo(models.Model):
    class DirectionChoices(models.TextChoices):
        ARRIVAL = "arrival", "Chegada"
        DEPARTURE = "departure", "Regresso"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    travel_plan = models.ForeignKey(
        "travel_plans.TravelPlan",
        on_delete=models.CASCADE,
        related_name="flights",
    )
    direction = models.CharField(max_length=20, choices=DirectionChoices.choices)
    flight_number = models.CharField(max_length=80)
    flight_date = models.DateField()
    flight_time = models.TimeField()
    airport = models.CharField(max_length=255)
    airline = models.CharField(max_length=255, blank=True)
    observations = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "travel_plan_flights"
        constraints = [
            models.UniqueConstraint(
                fields=["travel_plan", "direction"],
                name="travel_plan_unique_flight_per_direction",
            )
        ]
        indexes = [
            models.Index(fields=["travel_plan", "direction"]),
            models.Index(fields=["flight_date", "flight_time"]),
        ]

    def __str__(self) -> str:
        return f"{self.direction}:{self.flight_number}"


class HotelInfo(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    travel_plan = models.OneToOneField(
        "travel_plans.TravelPlan",
        on_delete=models.CASCADE,
        related_name="hotel",
    )
    hotel_name = models.CharField(max_length=255)
    address = models.CharField(max_length=255)
    checkin_date = models.DateField()
    checkin_time = models.TimeField()
    checkout_date = models.DateField()
    checkout_time = models.TimeField()
    room_number = models.CharField(max_length=50, blank=True)
    hotel_phone = models.CharField(max_length=50, blank=True)
    location_link = models.URLField(blank=True)
    observations = models.TextField(blank=True)

    class Meta:
        db_table = "travel_plan_hotels"

    def __str__(self) -> str:
        return self.hotel_name


class Transfer(models.Model):
    class StatusChoices(models.TextChoices):
        SCHEDULED = "scheduled", "Agendado"
        CONFIRMED = "confirmed", "Confirmado"
        COMPLETED = "completed", "Concluído"
        CANCELLED = "cancelled", "Cancelado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    travel_plan = models.ForeignKey(
        "travel_plans.TravelPlan",
        on_delete=models.CASCADE,
        related_name="transfers",
    )
    title = models.CharField(max_length=255)
    transfer_date = models.DateField()
    transfer_time = models.TimeField()
    origin = models.CharField(max_length=255)
    destination = models.CharField(max_length=255)
    observations = models.TextField(blank=True)
    status = models.CharField(
        max_length=20,
        choices=StatusChoices.choices,
        default=StatusChoices.SCHEDULED,
    )
    reminder_sent = models.BooleanField(default=False)
    confirmed_by_patient = models.BooleanField(default=False)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    display_order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "travel_plan_transfers"
        ordering = ["display_order", "transfer_date", "transfer_time"]
        indexes = [
            models.Index(fields=["travel_plan", "display_order"]),
            models.Index(fields=["transfer_date", "transfer_time"]),
            models.Index(fields=["status"]),
        ]

    def __str__(self) -> str:
        return self.title
