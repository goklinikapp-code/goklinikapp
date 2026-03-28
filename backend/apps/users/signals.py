from __future__ import annotations

from django.db import IntegrityError
from django.db.models import Q
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils.crypto import get_random_string

from .models import GoKlinikUser

REFERRAL_ALLOWED_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"


def generate_unique_referral_code() -> str:
    while True:
        candidate = get_random_string(8, allowed_chars=REFERRAL_ALLOWED_CHARS)
        if not GoKlinikUser.objects.filter(referral_code=candidate).exists():
            return candidate


def assign_referral_code_if_missing(instance: GoKlinikUser) -> str | None:
    # Any tenant-scoped user (except SaaS owner) can own a referral code.
    # This enables clinic-level referral links in admin surfaces.
    if instance.role == GoKlinikUser.RoleChoices.SUPER_ADMIN:
        return instance.referral_code
    if instance.referral_code:
        return instance.referral_code

    missing_code = Q(referral_code__isnull=True) | Q(referral_code="")
    for _ in range(10):
        candidate = generate_unique_referral_code()
        try:
            updated = (
                GoKlinikUser.objects.filter(
                    pk=instance.pk,
                )
                .filter(missing_code)
                .update(referral_code=candidate)
            )
        except IntegrityError:
            continue

        if updated:
            return candidate
        break

    return (
        GoKlinikUser.objects.filter(pk=instance.pk).values_list("referral_code", flat=True).first()
    )


def _assign_referral_code_on_create(instance: GoKlinikUser, created: bool) -> None:
    if not created:
        return

    assign_referral_code_if_missing(instance)


@receiver(
    post_save,
    sender=GoKlinikUser,
    dispatch_uid="users.assign_referral_code_from_goklinikuser",
)
def assign_referral_code_to_user_patient(
    sender, instance: GoKlinikUser, created: bool, **kwargs
):
    _assign_referral_code_on_create(instance, created)


@receiver(
    post_save,
    sender="patients.Patient",
    dispatch_uid="users.assign_referral_code_from_patient",
)
def assign_referral_code_to_patient_model(
    sender, instance: GoKlinikUser, created: bool, **kwargs
):
    _assign_referral_code_on_create(instance, created)
