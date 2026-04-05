from __future__ import annotations

import os

import firebase_admin
from firebase_admin import credentials


def _clean_env(name: str) -> str:
    return (os.getenv(name, "") or "").strip()


def _build_firebase_credentials_from_env() -> dict[str, str]:
    project_id = _clean_env("FIREBASE_PROJECT_ID")
    client_email = _clean_env("FIREBASE_CLIENT_EMAIL")
    private_key = (_clean_env("FIREBASE_PRIVATE_KEY")).replace("\\n", "\n")

    missing: list[str] = []
    if not project_id:
        missing.append("FIREBASE_PROJECT_ID")
    if not client_email:
        missing.append("FIREBASE_CLIENT_EMAIL")
    if not private_key:
        missing.append("FIREBASE_PRIVATE_KEY")

    if missing:
        raise RuntimeError(
            "Firebase env vars are missing: " + ", ".join(missing)
        )

    return {
        "type": "service_account",
        "project_id": project_id,
        "client_email": client_email,
        "private_key": private_key,
        "token_uri": "https://oauth2.googleapis.com/token",
    }


def initialize_firebase_from_env():
    if firebase_admin._apps:
        return firebase_admin.get_app()

    payload = _build_firebase_credentials_from_env()
    cred = credentials.Certificate(payload)
    return firebase_admin.initialize_app(cred)


if __name__ == "__main__":
    initialize_firebase_from_env()
    print("Firebase initialized via environment variables.")
