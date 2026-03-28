from __future__ import annotations

import json
import ssl
from dataclasses import dataclass
from decimal import Decimal
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings

class AIServiceError(Exception):
    pass


@dataclass
class AIRuntimeConfig:
    provider: str
    model_name: str
    endpoint_url: str
    api_key: str
    temperature: Decimal
    max_tokens: int


def _build_ssl_context() -> ssl.SSLContext:
    try:
        import certifi  # type: ignore

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def resolve_ai_runtime_config() -> AIRuntimeConfig:
    api_key = (getattr(settings, "GROK_API_KEY", "") or "").strip()

    if not api_key:
        raise AIServiceError("Grok API key is not configured in server environment.")

    model_name = (getattr(settings, "GROK_MODEL", "") or "grok-4-1-fast").strip()
    endpoint_url = (
        getattr(settings, "GROK_CHAT_ENDPOINT", "") or "https://api.x.ai/v1/chat/completions"
    ).strip()
    try:
        temperature = Decimal(str(getattr(settings, "GROK_TEMPERATURE", 0)))
    except Exception:
        temperature = Decimal("0")
    try:
        max_tokens = int(getattr(settings, "GROK_MAX_TOKENS", 600))
    except Exception:
        max_tokens = 600

    return AIRuntimeConfig(
        provider="grok",
        model_name=model_name,
        endpoint_url=endpoint_url,
        api_key=api_key,
        temperature=temperature,
        max_tokens=max_tokens,
    )


def request_chat_completion(*, messages: list[dict], config: AIRuntimeConfig) -> str:
    payload = {
        "messages": messages,
        "model": config.model_name,
        "stream": False,
        "temperature": float(config.temperature),
        "max_tokens": int(config.max_tokens),
    }

    body = json.dumps(payload).encode("utf-8")
    request = Request(
        config.endpoint_url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            # x.ai sits behind Cloudflare and may block default urllib clients
            # (HTTP 403 / error code 1010). A browser-like user-agent avoids that.
            "User-Agent": "GoKlinik/1.0 (+https://goklinik.com)",
            "Authorization": f"Bearer {config.api_key}",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=20, context=_build_ssl_context()) as response:
            response_body = response.read().decode("utf-8")
    except HTTPError as exc:
        detail = exc.read().decode("utf-8") if getattr(exc, "read", None) else str(exc)
        raise AIServiceError(f"AI provider returned HTTP {exc.code}: {detail[:300]}") from exc
    except URLError as exc:
        raise AIServiceError(f"Could not connect to AI provider: {exc}") from exc
    except Exception as exc:
        raise AIServiceError(f"Unexpected AI provider error: {exc}") from exc

    try:
        data = json.loads(response_body)
    except json.JSONDecodeError as exc:
        raise AIServiceError("Invalid AI response format.") from exc

    choices = data.get("choices") or []
    if not choices:
        raise AIServiceError("AI response did not include choices.")

    first = choices[0] or {}
    message = first.get("message") or {}
    content = (message.get("content") or "").strip()
    if not content:
        raise AIServiceError("AI returned an empty response.")
    return content
