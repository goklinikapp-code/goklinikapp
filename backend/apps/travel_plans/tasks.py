from __future__ import annotations

from datetime import datetime, timedelta

from celery import shared_task
from django.db import transaction
from django.utils import timezone

from apps.notifications.models import Notification

from .models import Transfer


@shared_task(name="travel_plans.send_transfer_reminders")
def send_transfer_reminders():
    now = timezone.localtime()
    window_end = now + timedelta(hours=2)

    candidates = (
        Transfer.objects.select_related("travel_plan", "travel_plan__tenant", "travel_plan__patient")
        .filter(
            status=Transfer.StatusChoices.CONFIRMED,
            reminder_sent=False,
            transfer_date__range=(now.date(), window_end.date()),
        )
        .order_by("transfer_date", "transfer_time")
    )

    notifications_to_create: list[Notification] = []
    transfer_ids_to_update: list[str] = []
    timezone_value = timezone.get_current_timezone()

    for transfer in candidates:
        transfer_datetime = timezone.make_aware(
            datetime.combine(transfer.transfer_date, transfer.transfer_time),
            timezone_value,
        )
        if transfer_datetime < now or transfer_datetime > window_end:
            continue

        travel_plan = transfer.travel_plan
        title = "O seu transfer esta proximo"
        time_text = transfer.transfer_time.strftime("%H:%M")
        body = (
            f"Seu transfer {transfer.title} esta agendado para hoje as {time_text} "
            f"em {transfer.origin}."
        )

        notifications_to_create.append(
            Notification(
                tenant=travel_plan.tenant,
                recipient=travel_plan.patient,
                title=title,
                body=body,
                notification_type=Notification.NotificationTypeChoices.SYSTEM,
                related_object_id=transfer.id,
            )
        )
        transfer_ids_to_update.append(str(transfer.id))

    if not transfer_ids_to_update:
        return {
            "checked": candidates.count(),
            "sent": 0,
        }

    with transaction.atomic():
        Notification.objects.bulk_create(notifications_to_create)
        Transfer.objects.filter(id__in=transfer_ids_to_update).update(reminder_sent=True)

    return {
        "checked": candidates.count(),
        "sent": len(transfer_ids_to_update),
    }
