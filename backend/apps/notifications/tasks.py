from __future__ import annotations

from celery import shared_task

from .services import NotificationAutomationService, NotificationService


@shared_task(name="notifications.send_appointment_confirmation_task")
def send_appointment_confirmation_task(appointment_id: str):
    return NotificationService.send_appointment_confirmation(appointment_id)


@shared_task(name="notifications.send_appointment_reminder_task")
def send_appointment_reminder_task(appointment_id: str):
    return NotificationService.send_appointment_reminder(appointment_id)


@shared_task(name="notifications.send_postop_daily_alert_task")
def send_postop_daily_alert_task(journey_id: str, day_number: int):
    return NotificationService.send_postop_daily_alert(journey_id, day_number)


@shared_task(name="notifications.execute_workflow_for_appointment_task")
def execute_workflow_for_appointment_task(workflow_id: str, appointment_id: str):
    return NotificationAutomationService.execute_workflow_for_appointment(
        workflow_id=workflow_id,
        appointment_id=appointment_id,
    )


@shared_task(name="notifications.dispatch_appointment_created_workflows_task")
def dispatch_appointment_created_workflows_task(appointment_id: str):
    return NotificationAutomationService.dispatch_appointment_created_workflows(appointment_id)


@shared_task(name="notifications.schedule_appointment_reminder_workflows_task")
def schedule_appointment_reminder_workflows_task(appointment_id: str):
    return NotificationAutomationService.schedule_appointment_reminder_workflows(appointment_id)


@shared_task(name="notifications.schedule_postop_followup_workflows_task")
def schedule_postop_followup_workflows_task(appointment_id: str):
    return NotificationAutomationService.schedule_postop_followup_workflows(appointment_id)


@shared_task(name="notifications.run_scheduled_notification_task")
def run_scheduled_notification_task(scheduled_notification_id: str):
    return NotificationAutomationService.execute_scheduled_notification(scheduled_notification_id)
