from __future__ import annotations

from typing import Any
from urllib.parse import urljoin, urlsplit, urlunsplit

from django.conf import settings

LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1"}
MEDIA_FIELD_NAMES = {
    "avatar",
    "interlocutor_avatar",
}


def _default_api_base_url() -> str:
    configured = str(getattr(settings, "API_BASE_URL", "") or "").strip()
    if configured:
        return configured.rstrip("/")
    return "http://127.0.0.1:8000" if settings.DEBUG else "https://api.goklinik.com"


def _is_local_host(hostname: str | None) -> bool:
    return (hostname or "").lower() in LOCAL_HOSTS


def _request_base_url(request) -> str:
    if request is None:
        return _default_api_base_url()
    try:
        built = (request.build_absolute_uri("/") or "").strip()
    except Exception:  # noqa: BLE001
        return _default_api_base_url()
    if not built:
        return _default_api_base_url()

    # Never propagate localhost in non-debug environments.
    parsed = urlsplit(built)
    if not settings.DEBUG and _is_local_host(parsed.hostname):
        return _default_api_base_url()
    return built.rstrip("/")


def _replace_origin(url: str, origin: str) -> str:
    current = urlsplit(url)
    base = urlsplit(origin if "://" in origin else f"https://{origin}")
    scheme = base.scheme or "https"
    netloc = base.netloc or base.path
    return urlunsplit((scheme, netloc, current.path, current.query, current.fragment))


def absolute_media_url(url: str | None, *, request=None) -> str:
    value = (url or "").strip()
    if not value:
        return ""

    base_url = _request_base_url(request)

    if value.startswith("//"):
        scheme = urlsplit(base_url).scheme or "https"
        value = f"{scheme}:{value}"

    parsed = urlsplit(value)
    if parsed.scheme and parsed.netloc:
        # Normalize localhost links in non-debug envs to configured API domain.
        if not settings.DEBUG and _is_local_host(parsed.hostname):
            return _replace_origin(value, _default_api_base_url())
        return value

    return urljoin(f"{base_url.rstrip('/')}/", value)


def _is_media_key(key: str) -> bool:
    key_lower = key.lower()
    return key_lower.endswith("_url") or key_lower in MEDIA_FIELD_NAMES


def normalize_media_payload(data: Any, *, request=None) -> Any:
    if isinstance(data, list):
        return [normalize_media_payload(item, request=request) for item in data]

    if isinstance(data, dict):
        message_type = str(data.get("message_type", "") or "").lower()
        normalized: dict[str, Any] = {}
        for key, value in data.items():
            if isinstance(value, str) and _is_media_key(key):
                normalized[key] = absolute_media_url(value, request=request)
                continue
            if isinstance(value, str) and key == "content" and message_type == "image":
                normalized[key] = absolute_media_url(value, request=request)
                continue
            normalized[key] = normalize_media_payload(value, request=request)
        return normalized

    return data


class AbsoluteMediaUrlsSerializerMixin:
    """
    Normalizes media-related URL fields in serializer output so clients always
    receive absolute URLs.
    """

    def to_representation(self, instance):  # type: ignore[override]
        payload = super().to_representation(instance)
        request = self.context.get("request") if hasattr(self, "context") else None
        return normalize_media_payload(payload, request=request)
