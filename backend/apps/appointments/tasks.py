from __future__ import annotations

from datetime import datetime, timedelta

from celery import shared_task
from django.utils import timezone

from apps.notifications.tasks import send_appointment_reminder_task
from apps.post_op.models import PostOpJourney
from apps.post_op.services import bootstrap_journey_checklist

from .models import Appointment


@shared_task(name="appointments.schedule_appointment_reminder")
def schedule_appointment_reminder(appointment_id: str) -> str:
    appointment = Appointment.objects.filter(id=appointment_id).first()
    if not appointment:
        return "appointment-not-found"

    scheduled_dt = timezone.make_aware(
        datetime.combine(appointment.appointment_date, appointment.appointment_time),
        timezone.get_current_timezone(),
    )
    reminder_eta = scheduled_dt - timedelta(hours=24)

    if reminder_eta <= timezone.now():
        send_appointment_reminder_task.delay(str(appointment.id))
        return "reminder-dispatched-immediately"

    send_appointment_reminder_task.apply_async(
        args=[str(appointment.id)],
        eta=reminder_eta,
    )
    return "reminder-scheduled"


@shared_task(name="appointments.create_postop_schedule")
def create_postop_schedule(appointment_id: str) -> str:
    surgery_appointment = Appointment.objects.filter(id=appointment_id).first()
    if not surgery_appointment:
        return "appointment-not-found"

    if surgery_appointment.appointment_type != Appointment.AppointmentTypeChoices.SURGERY:
        return "appointment-not-surgery"

    if surgery_appointment.status != Appointment.StatusChoices.COMPLETED:
        return "appointment-not-completed"

    postop_types = [
        (7, Appointment.AppointmentTypeChoices.POST_OP_7D),
        (30, Appointment.AppointmentTypeChoices.POST_OP_30D),
        (90, Appointment.AppointmentTypeChoices.POST_OP_90D),
    ]

    for days, app_type in postop_types:
        follow_up_date = surgery_appointment.appointment_date + timedelta(days=days)
        Appointment.objects.get_or_create(
            tenant=surgery_appointment.tenant,
            patient=surgery_appointment.patient,
            professional=surgery_appointment.professional,
            specialty=surgery_appointment.specialty,
            appointment_date=follow_up_date,
            appointment_time=surgery_appointment.appointment_time,
            appointment_type=app_type,
            defaults={
                "duration_minutes": surgery_appointment.duration_minutes,
                "status": Appointment.StatusChoices.PENDING,
                "notes": "Automatically generated post-op appointment.",
                "clinic_location": surgery_appointment.clinic_location,
                "created_by": surgery_appointment.created_by,
            },
        )

    journey, _ = PostOpJourney.objects.get_or_create(
        patient=surgery_appointment.patient,
        appointment=surgery_appointment,
        defaults={
            "specialty": surgery_appointment.specialty,
            "surgery_date": surgery_appointment.appointment_date,
            "status": PostOpJourney.StatusChoices.ACTIVE,
        },
    )
    bootstrap_journey_checklist(journey)

    return "postop-schedule-created"
