from __future__ import annotations

import json
import logging
from pathlib import Path

from django.conf import settings
from django.utils import timezone

from apps.appointments.models import Appointment
from apps.post_op.models import PostOpJourney

from .models import Notification, NotificationToken

logger = logging.getLogger(__name__)


class NotificationService:
    @staticmethod
    def _get_firebase_messaging():
        credential_path = getattr(settings, "FIREBASE_CREDENTIALS_PATH", None)
        if not credential_path:
            return None

        try:
            import firebase_admin
            from firebase_admin import credentials, messaging

            if not firebase_admin._apps:
                cred = credentials.Certificate(Path(credential_path))
                firebase_admin.initialize_app(cred)
            return messaging
        except Exception as exc:  # noqa: BLE001
            logger.warning("Firebase init failed: %s", exc)
            return None

    @classmethod
    def send_push(cls, user_id, title, body, data=None) -> int:
        user_tokens = NotificationToken.objects.filter(user_id=user_id, is_active=True)
        messaging = cls._get_firebase_messaging()
        sent_count = 0

        payload_data = {}
        if data:
            payload_data = {k: str(v) for k, v in data.items()}

        for token in user_tokens:
            if messaging:
                try:
                    message = messaging.Message(
                        token=token.device_token,
                        notification=messaging.Notification(title=title, body=body),
                        data=payload_data,
                    )
                    messaging.send(message)
                    sent_count += 1
                except Exception as exc:  # noqa: BLE001
                    logger.warning("Push send failed for user %s: %s", user_id, exc)
                    continue
            else:
                # Fallback for local/dev when FCM credentials are not configured.
                sent_count += 1

        return sent_count

    @classmethod
    def send_appointment_reminder(cls, appointment_id):
        appointment = Appointment.objects.select_related("patient", "tenant").filter(id=appointment_id).first()
        if not appointment:
            return "appointment-not-found"

        title = "Appointment Reminder"
        body = (
            f"You have an appointment on {appointment.appointment_date} at "
            f"{appointment.appointment_time.strftime('%H:%M')}."
        )

        notification = Notification.objects.create(
            tenant=appointment.tenant,
            recipient=appointment.patient,
            title=title,
            body=body,
            notification_type=Notification.NotificationTypeChoices.APPOINTMENT_REMINDER,
            related_object_id=appointment.id,
            sent_at=timezone.now(),
        )

        cls.send_push(
            user_id=appointment.patient_id,
            title=title,
            body=body,
            data={"notification_id": notification.id, "appointment_id": appointment.id},
        )

        return "ok"

    @classmethod
    def send_postop_daily_alert(cls, journey_id, day_number):
        journey = PostOpJourney.objects.select_related("patient", "patient__tenant").filter(id=journey_id).first()
        if not journey:
            return "journey-not-found"

        title = f"Post-op Day {day_number}"
        body = "Remember to complete your checklist and upload your evolution photo."

        notification = Notification.objects.create(
            tenant=journey.patient.tenant,
            recipient=journey.patient,
            title=title,
            body=body,
            notification_type=Notification.NotificationTypeChoices.POSTOP_ALERT,
            related_object_id=journey.id,
            sent_at=timezone.now(),
        )

        cls.send_push(
            user_id=journey.patient_id,
            title=title,
            body=body,
            data={"notification_id": notification.id, "journey_id": journey.id, "day": day_number},
        )
        return "ok"

    @staticmethod
    def mark_as_read(notification_id, user_id):
        notification = Notification.objects.filter(id=notification_id, recipient_id=user_id).first()
        if not notification:
            return None
        notification.is_read = True
        notification.save(update_fields=["is_read"])
        return notification
