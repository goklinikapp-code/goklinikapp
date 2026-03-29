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

# Railway target-port mismatches can happen between 8000 and 8080.
# To avoid hard downtime, always bind both defaults, and also SAFE_PORT if it differs.
set -- \
  --bind "0.0.0.0:8000" \
  --bind "0.0.0.0:8080"

if [ "$SAFE_PORT" != "8000" ] && [ "$SAFE_PORT" != "8080" ]; then
  set -- "$@" --bind "0.0.0.0:${SAFE_PORT}"
fi

exec gunicorn config.wsgi:application "$@" \
  --workers=3 \
  --timeout=120
