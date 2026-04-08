from __future__ import annotations

import os
import sys
from pathlib import Path
from urllib.parse import quote, unquote

import dj_database_url
from dotenv import load_dotenv

ROOT_DIR = Path(__file__).resolve().parents[2]
APPS_DIR = ROOT_DIR / "apps"

load_dotenv(ROOT_DIR / ".env")


def clean_env_value(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = value.strip()
    if len(stripped) >= 2 and stripped[0] == stripped[-1] and stripped[0] in {"'", '"'}:
        return stripped[1:-1]
    return stripped


def env(name: str, default: str | None = None) -> str | None:
    return clean_env_value(os.getenv(name, default))


def env_bool(name: str, default: bool = False) -> bool:
    value = clean_env_value(os.getenv(name))
    if value is None:
        return default
    return value.lower() in {"1", "true", "yes", "on"}


def env_int(name: str, default: int) -> int:
    value = clean_env_value(os.getenv(name))
    if value is None:
        return default
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def env_list(name: str, default: list[str] | None = None) -> list[str]:
    value = clean_env_value(os.getenv(name))
    if not value:
        return default or []
    return [item.strip() for item in value.split(",") if item.strip()]


def normalize_database_url(raw_url: str) -> str:
    if "://" not in raw_url or "@" not in raw_url:
        return raw_url

    scheme, rest = raw_url.split("://", 1)
    credentials, tail = rest.split("@", 1)
    if ":" not in credentials:
        return raw_url

    user, password = credentials.split(":", 1)
    safe_password = quote(unquote(password), safe="")
    return f"{scheme}://{user}:{safe_password}@{tail}"


SECRET_KEY = env("DJANGO_SECRET_KEY", "django-insecure-change-me")
DEBUG = env_bool("DJANGO_DEBUG", False)
DEFAULT_ALLOWED_HOSTS = [
    "api.goklinik.com",
    "goklinik.com",
    "www.goklinik.com",
    "localhost",
    "127.0.0.1",
]
ALLOWED_HOSTS = sorted(set(DEFAULT_ALLOWED_HOSTS + env_list("DJANGO_ALLOWED_HOSTS", [])))

DEFAULT_API_BASE_URL = "http://127.0.0.1:8000" if DEBUG else "https://api.goklinik.com"
API_BASE_URL = (env("API_BASE_URL", DEFAULT_API_BASE_URL) or DEFAULT_API_BASE_URL).rstrip("/")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "rest_framework",
    "rest_framework_simplejwt",
    "drf_spectacular",
    "storages",
    "apps.tenants.apps.TenantsConfig",
    "apps.users.apps.UsersConfig",
    "apps.patients.apps.PatientsConfig",
    "apps.appointments.apps.AppointmentsConfig",
    "apps.post_op.apps.PostOpConfig",
    "apps.chat.apps.ChatConfig",
    "apps.notifications.apps.NotificationsConfig",
    "apps.financial.apps.FinancialConfig",
    "apps.referrals.apps.ReferralsConfig",
    "apps.medical_records.apps.MedicalRecordsConfig",
    "apps.pre_operatory.apps.PreOperatoryConfig",
    "apps.travel_plans.apps.TravelPlansConfig",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [ROOT_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ]
        },
    }
]

DEFAULT_DATABASE_URL = (
    "postgresql://postgres:postgres@localhost:5432/postgres"
)
DIRECT_DATABASE_URL = env("DATABASE_URL", DEFAULT_DATABASE_URL) or DEFAULT_DATABASE_URL
DATABASE_POOLER_URL = env("DATABASE_POOLER_URL")
DATABASE_SSL_REQUIRE = env_bool("DATABASE_SSL_REQUIRE", True)
DATABASE_CONN_MAX_AGE = env_int("DATABASE_CONN_MAX_AGE", 0 if DEBUG else 600)
DATABASE_CONNECT_TIMEOUT = env_int("DATABASE_CONNECT_TIMEOUT", 10)

database_parse_errors: list[str] = []
database_candidates: list[tuple[str, str]] = []
if DATABASE_POOLER_URL:
    database_candidates.append(("DATABASE_POOLER_URL", DATABASE_POOLER_URL))
database_candidates.append(("DATABASE_URL", DIRECT_DATABASE_URL))

resolved_database_config = None
for source_name, candidate_url in database_candidates:
    try:
        resolved_database_config = dj_database_url.parse(
            normalize_database_url(candidate_url),
            conn_max_age=DATABASE_CONN_MAX_AGE,
            ssl_require=DATABASE_SSL_REQUIRE,
        )
        break
    except Exception as exc:  # noqa: BLE001
        database_parse_errors.append(f"{source_name}: {exc}")

if resolved_database_config is None:
    details = "; ".join(database_parse_errors) or "No DATABASE_URL candidate was provided."
    raise RuntimeError(f"Invalid database configuration. Details: {details}")

resolved_database_config.setdefault("OPTIONS", {})
resolved_database_config["OPTIONS"].setdefault("connect_timeout", DATABASE_CONNECT_TIMEOUT)

DATABASES = {"default": resolved_database_config}

if env_bool("USE_SQLITE_FOR_TESTS", True) and "test" in sys.argv:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": ROOT_DIR / "test_db.sqlite3",
        }
    }

AUTH_USER_MODEL = "users.GoKlinikUser"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = env("TIME_ZONE", "Europe/Istanbul")
USE_I18N = True
USE_TZ = True

STATIC_URL = "/static/"
STATIC_ROOT = ROOT_DIR / "staticfiles"

SUPABASE_PROJECT_ID = env("SUPABASE_PROJECT_ID", "your-supabase-project-id")
SUPABASE_URL = env("SUPABASE_URL", "https://your-project-id.supabase.co")
SUPABASE_SERVICE_ROLE_KEY = env("SUPABASE_SERVICE_ROLE_KEY", "")
SUPABASE_ANON_KEY = env(
    "SUPABASE_ANON_KEY",
    "",
)
SUPABASE_AUTH_STRICT = env_bool("SUPABASE_AUTH_STRICT", False)
SUPABASE_PASSWORD_RESET_REDIRECT = env(
    "SUPABASE_PASSWORD_RESET_REDIRECT", "https://goklinik.com/reset-password"
)
SUPABASE_OUTBOUND_EMAILS_ENABLED = env_bool("SUPABASE_OUTBOUND_EMAILS_ENABLED", not DEBUG)
REFERRAL_BASE_URL = (
    env("REFERRAL_BASE_URL", "https://goklinik.com/ref") or "https://goklinik.com/ref"
).rstrip("/")
SUPABASE_ASSETS_BUCKET = env("SUPABASE_ASSETS_BUCKET", "clinic-assets")

SUPABASE_STORAGE_BUCKET = (
    env("SUPABASE_STORAGE_BUCKET", SUPABASE_ASSETS_BUCKET) or SUPABASE_ASSETS_BUCKET
)
AWS_ACCESS_KEY_ID = env("SUPABASE_STORAGE_ACCESS_KEY", "supabase")
_supabase_storage_secret = env("SUPABASE_STORAGE_SECRET_KEY", "") or ""
if _supabase_storage_secret.startswith("replace-with-"):
    _supabase_storage_secret = ""
AWS_SECRET_ACCESS_KEY = _supabase_storage_secret or env(
    "SUPABASE_SERVICE_ROLE_KEY", SUPABASE_ANON_KEY
)
AWS_STORAGE_BUCKET_NAME = SUPABASE_STORAGE_BUCKET
AWS_S3_REGION_NAME = env("SUPABASE_STORAGE_REGION", "us-east-1")
AWS_S3_SIGNATURE_VERSION = "s3v4"
AWS_S3_ENDPOINT_URL = env("SUPABASE_S3_ENDPOINT", f"{SUPABASE_URL}/storage/v1/s3")
AWS_DEFAULT_ACL = None
AWS_QUERYSTRING_AUTH = False
AWS_S3_FILE_OVERWRITE = False
DEFAULT_FILE_STORAGE = "storages.backends.s3boto3.S3Boto3Storage"
STORAGES = {
    "default": {"BACKEND": "storages.backends.s3boto3.S3Boto3Storage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}
MEDIA_ROOT = Path(env("MEDIA_ROOT", str(ROOT_DIR / "media")) or str(ROOT_DIR / "media"))
MEDIA_URL = "/media/"

DEFAULT_CORS_ALLOWED_ORIGINS = [
    "https://goklinik.com",
    "https://www.goklinik.com",
    "https://launch.goklinik.com",
    "http://localhost:3000",
    "http://localhost:5173",
    "http://127.0.0.1:5173",
    "capacitor://localhost",
]
CORS_ALLOWED_ORIGINS = sorted(
    set(DEFAULT_CORS_ALLOWED_ORIGINS + env_list("CORS_ALLOWED_ORIGINS", []))
)
DEFAULT_CORS_ALLOWED_ORIGIN_REGEXES = [
    r"^https:\/\/([a-z0-9-]+\.)?goklinik\.com$",
]
CORS_ALLOWED_ORIGIN_REGEXES = sorted(
    set(DEFAULT_CORS_ALLOWED_ORIGIN_REGEXES + env_list("CORS_ALLOWED_ORIGIN_REGEXES", []))
)
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_ALL_HEADERS = True
CORS_ALLOW_METHODS = [
    "GET",
    "POST",
    "PUT",
    "PATCH",
    "DELETE",
    "OPTIONS",
]
CSRF_TRUSTED_ORIGINS = sorted(
    {
        origin
        for origin in CORS_ALLOWED_ORIGINS
        if origin.startswith("http://") or origin.startswith("https://")
    }
)

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 10,
}

from datetime import timedelta

from celery.schedules import crontab

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(hours=1),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": False,
    "BLACKLIST_AFTER_ROTATION": False,
    "ALGORITHM": "HS256",
    "SIGNING_KEY": SECRET_KEY,
    "AUTH_HEADER_TYPES": ("Bearer",),
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Go Klinik API",
    "DESCRIPTION": "Clinical SaaS Platform API",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "ENUM_NAME_OVERRIDES": {
        "AppointmentStatusEnum": "apps.appointments.models.Appointment.StatusChoices",
        "PatientStatusEnum": "apps.patients.models.Patient.StatusChoices",
        "PostOpJourneyStatusEnum": "apps.post_op.models.PostOpJourney.StatusChoices",
        "TransactionStatusEnum": "apps.financial.models.Transaction.StatusChoices",
    },
}

CELERY_BROKER_URL = env("CELERY_BROKER_URL", "redis://localhost:6379/0")
CELERY_RESULT_BACKEND = env("CELERY_RESULT_BACKEND", CELERY_BROKER_URL)
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE = TIME_ZONE
CELERY_BEAT_SCHEDULE = {
    "travel-plan-transfer-reminders-hourly": {
        "task": "travel_plans.send_transfer_reminders",
        "schedule": crontab(minute=0),
    },
}

EMAIL_BACKEND = env(
    "EMAIL_BACKEND", "django.core.mail.backends.console.EmailBackend"
)
DEFAULT_FROM_EMAIL = env("DEFAULT_FROM_EMAIL", "no-reply@goklinik.com")
RESEND_API_KEY = env("RESEND_API_KEY", "")
RESEND_FROM_EMAIL = env("RESEND_FROM_EMAIL", DEFAULT_FROM_EMAIL)
GROK_API_KEY = env("GROK_API_KEY", "")
GROK_MODEL = env("GROK_MODEL", "grok-4-1-fast")
GROK_CHAT_ENDPOINT = env("GROK_CHAT_ENDPOINT", "https://api.x.ai/v1/chat/completions")
FRONTEND_BASE_URL = env("FRONTEND_BASE_URL", "https://goklinik.com")
DEFAULT_LAUNCH_SIGNUP_BASE_URL = "http://localhost:5173" if DEBUG else "https://launch.goklinik.com"
LAUNCH_SIGNUP_BASE_URL = (
    env("LAUNCH_SIGNUP_BASE_URL", DEFAULT_LAUNCH_SIGNUP_BASE_URL) or DEFAULT_LAUNCH_SIGNUP_BASE_URL
).rstrip("/")
LAUNCH_SIGNUP_PATH = env("LAUNCH_SIGNUP_PATH", "")
LAUNCH_REF_QUERY_PARAM = env("LAUNCH_REF_QUERY_PARAM", "")
TEAM_INVITE_LOGIN_PATH = env("TEAM_INVITE_LOGIN_PATH", "/login")
FIREBASE_PROJECT_ID = env("FIREBASE_PROJECT_ID", "")
FIREBASE_CLIENT_EMAIL = env("FIREBASE_CLIENT_EMAIL", "")
FIREBASE_PRIVATE_KEY = (env("FIREBASE_PRIVATE_KEY", "") or "").replace("\\n", "\n")
PUSH_MAX_PER_USER_PER_HOUR = env_int("PUSH_MAX_PER_USER_PER_HOUR", 20)
APPOINTMENT_REMINDER_HOURS_BEFORE = env_int("APPOINTMENT_REMINDER_HOURS_BEFORE", 24)

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
