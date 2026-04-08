from __future__ import annotations

from datetime import datetime, time

from django.db import migrations, models
from django.utils import timezone

ACTIVE_STATUSES = {"pending", "confirmed", "in_progress"}
PRIMARY_FLOW_TYPES = {"first_visit", "return", "surgery"}


def _created_sort_value(value):
    if value is None:
        return 0.0
    if timezone.is_aware(value):
        value = timezone.localtime(value)
    return value.timestamp()


def _priority_sort_key(appointment, *, today):
    appointment_time = appointment.appointment_time or time(0, 0)
    minute_of_day = appointment_time.hour * 60 + appointment_time.minute
    created_rank = _created_sort_value(appointment.created_at)

    if appointment.appointment_date and appointment.appointment_date >= today:
        return (
            0,
            appointment.appointment_date.toordinal(),
            minute_of_day,
            created_rank,
        )

    date_rank = appointment.appointment_date.toordinal() if appointment.appointment_date else -1
    return (
        1,
        -date_rank,
        -minute_of_day,
        -created_rank,
    )


def _normalize_group(appointments, note: str):
    if len(appointments) <= 1:
        return

    today = timezone.localdate()
    keep = min(appointments, key=lambda item: _priority_sort_key(item, today=today))

    for appointment in appointments:
        if appointment.id == keep.id:
            continue
        existing_notes = (appointment.internal_notes or "").strip()
        appointment.internal_notes = (
            f"{existing_notes}\n\n{note}".strip() if existing_notes else note
        )
        appointment.status = "rescheduled"
        appointment.save(update_fields=["status", "internal_notes", "updated_at"])


def normalize_active_appointment_conflicts(apps, schema_editor):
    Appointment = apps.get_model("appointments", "Appointment")

    migration_note = (
        f"System normalization on {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC: "
        "auto-rescheduled duplicate active appointment to enforce patient flow constraints."
    )

    same_type_groups = {}
    queryset = Appointment.objects.filter(status__in=ACTIVE_STATUSES).order_by(
        "tenant_id",
        "patient_id",
        "appointment_type",
        "appointment_date",
        "appointment_time",
        "created_at",
    )
    for appointment in queryset.iterator():
        key = (appointment.tenant_id, appointment.patient_id, appointment.appointment_type)
        same_type_groups.setdefault(key, []).append(appointment)

    for appointments in same_type_groups.values():
        _normalize_group(appointments, migration_note)

    primary_groups = {}
    queryset = Appointment.objects.filter(
        status__in=ACTIVE_STATUSES,
        appointment_type__in=PRIMARY_FLOW_TYPES,
    ).order_by(
        "tenant_id",
        "patient_id",
        "appointment_date",
        "appointment_time",
        "created_at",
    )
    for appointment in queryset.iterator():
        key = (appointment.tenant_id, appointment.patient_id)
        primary_groups.setdefault(key, []).append(appointment)

    for appointments in primary_groups.values():
        _normalize_group(appointments, migration_note)


class Migration(migrations.Migration):

    dependencies = [
        ("appointments", "0004_appointment_clinic_location"),
    ]

    operations = [
        migrations.RunPython(normalize_active_appointment_conflicts, migrations.RunPython.noop),
        migrations.AddConstraint(
            model_name="appointment",
            constraint=models.UniqueConstraint(
                condition=models.Q(
                    ("status__in", ["pending", "confirmed", "in_progress"]),
                ),
                fields=("tenant", "patient", "appointment_type"),
                name="uniq_active_patient_type_per_tenant",
            ),
        ),
        migrations.AddConstraint(
            model_name="appointment",
            constraint=models.UniqueConstraint(
                condition=models.Q(
                    ("appointment_type__in", ["first_visit", "return", "surgery"]),
                    ("status__in", ["pending", "confirmed", "in_progress"]),
                ),
                fields=("tenant", "patient"),
                name="uniq_active_primary_flow_per_patient",
            ),
        ),
    ]
