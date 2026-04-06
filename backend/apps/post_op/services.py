from __future__ import annotations

from datetime import date

from django.utils import timezone

from apps.post_op.models import PostOpChecklist, PostOpJourney, PostOpProtocol


def bootstrap_journey_checklist(journey: PostOpJourney) -> None:
    if not journey.specialty_id:
        return

    protocols = PostOpProtocol.objects.filter(specialty_id=journey.specialty_id)
    for protocol in protocols:
        PostOpChecklist.objects.get_or_create(
            journey=journey,
            day_number=protocol.day_number,
            item_text=protocol.title,
        )


def auto_complete_expired_journeys(
    *,
    patient_id: str | None = None,
    tenant_id: str | None = None,
    reference_date: date | None = None,
) -> int:
    today = reference_date or timezone.localdate()
    queryset = PostOpJourney.objects.filter(
        status=PostOpJourney.StatusChoices.ACTIVE,
        end_date__lt=today,
    )
    if patient_id:
        queryset = queryset.filter(patient_id=patient_id)
    if tenant_id:
        queryset = queryset.filter(patient__tenant_id=tenant_id)

    return queryset.update(
        status=PostOpJourney.StatusChoices.COMPLETED,
        updated_at=timezone.now(),
    )
