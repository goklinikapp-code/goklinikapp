from __future__ import annotations

from celery import shared_task

from .services import NotificationService


@shared_task(name="notifications.send_appointment_reminder_task")
def send_appointment_reminder_task(appointment_id: str):
    return NotificationService.send_appointment_reminder(appointment_id)


@shared_task(name="notifications.send_postop_daily_alert_task")
def send_postop_daily_alert_task(journey_id: str, day_number: int):
    return NotificationService.send_postop_daily_alert(journey_id, day_number)
