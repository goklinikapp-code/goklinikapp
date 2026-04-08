from __future__ import annotations

from functools import lru_cache
from urllib.parse import quote, unquote, urlsplit

import requests

from django.conf import settings
from supabase import Client, create_client


class SupabaseStorageError(Exception):
    """Base error for Supabase storage interactions."""


class SupabaseStorageConfigError(SupabaseStorageError):
    """Raised when required Supabase settings are missing."""


class SupabaseStorageUploadError(SupabaseStorageError):
    """Raised when an upload to Supabase fails."""


def _safe_setting(name: str, fallback: str = "") -> str:
    value = getattr(settings, name, fallback)
    return (value or fallback).strip()


def _service_role_key() -> str:
    return _safe_setting("SUPABASE_SERVICE_ROLE_KEY")


def _resolve_bucket_name() -> str:
    return (
        _safe_setting("SUPABASE_ASSETS_BUCKET")
        or _safe_setting("SUPABASE_STORAGE_BUCKET")
        or "clinic-assets"
    )


def _supabase_url() -> str:
    return _safe_setting("SUPABASE_URL")


def _normalize_path(path: str) -> str:
    normalized = (path or "").strip().strip("/")
    if not normalized:
        raise SupabaseStorageUploadError("Storage path is required.")
    return normalized


def _build_storage_object_url(path: str) -> str:
    normalized_path = _normalize_path(path)
    base_url = _supabase_url()
    if not base_url:
        raise SupabaseStorageConfigError("SUPABASE_URL is not configured.")
    bucket = _resolve_bucket_name()
    encoded_path = quote(normalized_path, safe="/")
    return f"{base_url.rstrip('/')}/storage/v1/object/{bucket}/{encoded_path}"


def _build_storage_public_url(path: str) -> str:
    normalized_path = _normalize_path(path)
    base_url = _supabase_url()
    if not base_url:
        raise SupabaseStorageConfigError("SUPABASE_URL is not configured.")
    bucket = _resolve_bucket_name()
    encoded_path = quote(normalized_path, safe="/")
    return f"{base_url.rstrip('/')}/storage/v1/object/public/{bucket}/{encoded_path}"


def _uses_secret_style_key() -> bool:
    return _service_role_key().startswith("sb_secret_")


def _auth_headers(*, content_type: str | None = None, upsert: bool | None = None) -> dict[str, str]:
    key = _service_role_key()
    if not key:
        raise SupabaseStorageConfigError("SUPABASE_SERVICE_ROLE_KEY is not configured.")

    headers = {
        "Authorization": f"Bearer {key}",
        "apikey": key,
    }
    if content_type:
        headers["content-type"] = content_type
    if upsert is not None:
        headers["x-upsert"] = "true" if upsert else "false"
    return headers


def _upload_file_via_http(*, payload: bytes, content_type: str, normalized_path: str) -> None:
    endpoint = _build_storage_object_url(normalized_path)
    try:
        response = requests.post(
            endpoint,
            headers=_auth_headers(content_type=content_type, upsert=False),
            data=payload,
            timeout=30,
        )
    except requests.RequestException as exc:
        raise SupabaseStorageUploadError("Failed to upload file to Supabase Storage.") from exc

    if response.status_code not in {200, 201}:
        detail = response.text.strip()[:300]
        raise SupabaseStorageUploadError(
            f"Failed to upload file to Supabase Storage. Status {response.status_code}: {detail}"
        )


def _delete_file_via_http(*, normalized_path: str) -> None:
    endpoint = _build_storage_object_url(normalized_path)
    try:
        response = requests.delete(
            endpoint,
            headers=_auth_headers(),
            timeout=30,
        )
    except requests.RequestException as exc:
        raise SupabaseStorageError("Failed to delete file from Supabase Storage.") from exc

    if response.status_code not in {200, 204}:
        detail = response.text.strip()[:300]
        raise SupabaseStorageError(
            f"Failed to delete file from Supabase Storage. Status {response.status_code}: {detail}"
        )


def _extract_storage_path_from_url(url: str) -> str | None:
    value = (url or "").strip()
    if not value:
        return None

    bucket_name = _resolve_bucket_name()
    parsed = urlsplit(value)
    path_part = unquote(parsed.path or "").strip()

    if path_part:
        marker = f"/storage/v1/object/public/{bucket_name}/"
        marker_index = path_part.find(marker)
        if marker_index >= 0:
            return _normalize_path(path_part[marker_index + len(marker) :])

        bucket_marker = f"/{bucket_name}/"
        bucket_index = path_part.find(bucket_marker)
        if bucket_index >= 0:
            return _normalize_path(path_part[bucket_index + len(bucket_marker) :])

    compact = unquote(value).strip().strip("/")
    if compact.startswith(f"{bucket_name}/"):
        return _normalize_path(compact[len(bucket_name) + 1 :])

    public_prefix = f"storage/v1/object/public/{bucket_name}/"
    if compact.startswith(public_prefix):
        return _normalize_path(compact[len(public_prefix) :])

    return None


@lru_cache(maxsize=1)
def _get_supabase_client() -> Client:
    supabase_url = _supabase_url()
    service_role_key = _service_role_key()

    if not supabase_url:
        raise SupabaseStorageConfigError("SUPABASE_URL is not configured.")
    if not service_role_key:
        raise SupabaseStorageConfigError("SUPABASE_SERVICE_ROLE_KEY is not configured.")

    return create_client(supabase_url, service_role_key)


def upload_file(file, path: str) -> str:
    normalized_path = _normalize_path(path)
    bucket_name = _resolve_bucket_name()
    content_type = (getattr(file, "content_type", "") or "application/octet-stream").lower()

    try:
        if hasattr(file, "seek"):
            file.seek(0)
        payload = file.read()
    except Exception as exc:  # noqa: BLE001
        raise SupabaseStorageUploadError("Could not read uploaded file.") from exc

    if isinstance(payload, str):
        payload = payload.encode("utf-8")
    if not payload:
        raise SupabaseStorageUploadError("Uploaded file is empty.")

    if _uses_secret_style_key():
        _upload_file_via_http(
            payload=payload,
            content_type=content_type,
            normalized_path=normalized_path,
        )
    else:
        try:
            storage = _get_supabase_client().storage.from_(bucket_name)
            storage.upload(
                path=normalized_path,
                file=payload,
                file_options={
                    "content-type": content_type,
                    "upsert": "false",
                    "cache-control": "3600",
                },
            )
        except Exception as exc:  # noqa: BLE001
            raise SupabaseStorageUploadError("Failed to upload file to Supabase Storage.") from exc

    return get_public_url(normalized_path)


def get_public_url(path: str) -> str:
    normalized_path = _normalize_path(path)

    if _uses_secret_style_key():
        return _build_storage_public_url(normalized_path)

    bucket_name = _resolve_bucket_name()

    try:
        raw_url = _get_supabase_client().storage.from_(bucket_name).get_public_url(normalized_path)
    except Exception as exc:  # noqa: BLE001
        raise SupabaseStorageError("Failed to generate Supabase public URL.") from exc

    if isinstance(raw_url, dict):
        public_url = (
            raw_url.get("publicURL")
            or raw_url.get("publicUrl")
            or raw_url.get("public_url")
            or ""
        )
    else:
        public_url = str(raw_url or "")

    public_url = public_url.strip()
    if not public_url:
        raise SupabaseStorageError("Supabase did not return a public URL.")
    return public_url


def delete_file(path_or_url: str) -> None:
    normalized = _extract_storage_path_from_url(path_or_url)
    if not normalized:
        normalized = _normalize_path(path_or_url)

    if _uses_secret_style_key():
        _delete_file_via_http(normalized_path=normalized)
        return

    bucket_name = _resolve_bucket_name()
    try:
        _get_supabase_client().storage.from_(bucket_name).remove([normalized])
    except Exception as exc:  # noqa: BLE001
        raise SupabaseStorageError("Failed to delete file from Supabase Storage.") from exc
