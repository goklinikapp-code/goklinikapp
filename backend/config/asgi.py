import os

from django.core.asgi import get_asgi_application


def _sanitize_settings_module() -> None:
    raw = os.getenv("DJANGO_SETTINGS_MODULE")
    if raw and len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in {"'", '"'}:
        os.environ["DJANGO_SETTINGS_MODULE"] = raw[1:-1]


_sanitize_settings_module()
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")

application = get_asgi_application()
