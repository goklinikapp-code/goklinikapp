#!/usr/bin/env sh
set -eu

# Railway can accidentally receive PORT as a literal string like "$PORT".
# Accept only numeric values and fallback safely to 8000.
RAW_PORT="${PORT:-8000}"
case "$RAW_PORT" in
  ''|*[!0-9]*)
    SAFE_PORT=8000
    ;;
  *)
    SAFE_PORT="$RAW_PORT"
    ;;
esac

exec gunicorn config.wsgi:application \
  --bind "0.0.0.0:${SAFE_PORT}" \
  --workers=3 \
  --timeout=120
