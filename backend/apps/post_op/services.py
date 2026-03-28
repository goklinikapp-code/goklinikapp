from __future__ import annotations

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
