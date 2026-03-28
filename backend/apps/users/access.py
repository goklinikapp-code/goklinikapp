from __future__ import annotations

from collections.abc import Iterable

from .models import GoKlinikUser


ACCESS_PERMISSION_KEYS = (
    "dashboard",
    "app",
    "patients",
    "schedule",
    "reports",
    "referrals",
    "team",
    "automations",
    "settings",
    "tutorials",
)

ALL_ACCESS_PERMISSIONS = list(ACCESS_PERMISSION_KEYS)

DEFAULT_ROLE_PERMISSIONS: dict[str, list[str]] = {
    GoKlinikUser.RoleChoices.CLINIC_MASTER: ALL_ACCESS_PERMISSIONS,
    GoKlinikUser.RoleChoices.SURGEON: [
        "dashboard",
        "app",
        "patients",
        "schedule",
        "reports",
    ],
    GoKlinikUser.RoleChoices.SECRETARY: [
        "dashboard",
        "app",
        "patients",
        "schedule",
        "reports",
    ],
    GoKlinikUser.RoleChoices.NURSE: [
        "dashboard",
        "app",
        "patients",
        "schedule",
    ],
    GoKlinikUser.RoleChoices.SUPER_ADMIN: [],
    GoKlinikUser.RoleChoices.PATIENT: [],
}


def normalize_access_permissions(values: Iterable[str] | None) -> list[str]:
    if not values:
        return []
    normalized: list[str] = []
    for raw_value in values:
        value = (raw_value or "").strip().lower()
        if value in ACCESS_PERMISSION_KEYS and value not in normalized:
            normalized.append(value)
    return normalized


def resolve_access_permissions_for_role(role: str, requested_values: Iterable[str] | None) -> list[str]:
    if role == GoKlinikUser.RoleChoices.CLINIC_MASTER:
        return list(ALL_ACCESS_PERMISSIONS)
    if role in {GoKlinikUser.RoleChoices.SUPER_ADMIN, GoKlinikUser.RoleChoices.PATIENT}:
        return []

    normalized = normalize_access_permissions(requested_values)
    if normalized:
        return normalized
    return list(DEFAULT_ROLE_PERMISSIONS.get(role, []))

