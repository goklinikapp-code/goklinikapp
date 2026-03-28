from __future__ import annotations

import logging

from django.conf import settings
from supabase import Client, create_client

logger = logging.getLogger(__name__)


def get_supabase_client() -> Client | None:
    if not settings.SUPABASE_URL or not settings.SUPABASE_ANON_KEY:
        return None
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)


def supabase_sign_up(email: str, password: str, metadata: dict | None = None) -> bool:
    if not settings.SUPABASE_OUTBOUND_EMAILS_ENABLED:
        logger.info(
            "Skipping Supabase sign-up email for %s because SUPABASE_OUTBOUND_EMAILS_ENABLED is false.",
            email,
        )
        return False

    client = get_supabase_client()
    if not client:
        return False

    try:
        payload = {"email": email, "password": password}
        if metadata:
            payload["options"] = {"data": metadata}
        client.auth.sign_up(payload)
        return True
    except Exception as exc:  # noqa: BLE001
        logger.warning("Supabase sign-up failed for %s: %s", email, exc)
        return False


def supabase_sign_in(email: str, password: str) -> bool:
    client = get_supabase_client()
    if not client:
        return False

    try:
        client.auth.sign_in_with_password({"email": email, "password": password})
        return True
    except Exception as exc:  # noqa: BLE001
        logger.warning("Supabase sign-in failed for %s: %s", email, exc)
        return False


def supabase_send_reset_password(email: str) -> bool:
    if not settings.SUPABASE_OUTBOUND_EMAILS_ENABLED:
        logger.info(
            "Skipping Supabase reset-password email for %s because SUPABASE_OUTBOUND_EMAILS_ENABLED is false.",
            email,
        )
        return False

    client = get_supabase_client()
    if not client:
        return False

    try:
        client.auth.reset_password_email(
            email,
            {"redirect_to": settings.SUPABASE_PASSWORD_RESET_REDIRECT},
        )
        return True
    except Exception as exc:  # noqa: BLE001
        logger.warning("Supabase reset password failed for %s: %s", email, exc)
        return False
