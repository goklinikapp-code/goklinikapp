#!/usr/bin/env python
import os
import sys


def _sanitize_settings_module() -> None:
    raw = os.getenv("DJANGO_SETTINGS_MODULE")
    if raw and len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in {"'", '"'}:
        os.environ["DJANGO_SETTINGS_MODULE"] = raw[1:-1]


def main() -> None:
    _sanitize_settings_module()
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and available on your "
            "PYTHONPATH environment variable?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
