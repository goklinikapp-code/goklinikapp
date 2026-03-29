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


def env(name: str, default: str | None = None) -> str | None:
    return os.getenv(name, default)


def env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return int(value.strip())
    except (TypeError, ValueError):
        return default


def env_list(name: str, default: list[str] | None = None) -> list[str]:
    value = os.getenv(name)
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
DATABASE_URL = env("DATABASE_URL", DEFAULT_DATABASE_URL) or DEFAULT_DATABASE_URL
DATABASE_POOLER_URL = env("DATABASE_POOLER_URL")
if DATABASE_POOLER_URL:
    DATABASE_URL = DATABASE_POOLER_URL
DATABASE_SSL_REQUIRE = env_bool("DATABASE_SSL_REQUIRE", True)
DATABASE_CONN_MAX_AGE = env_int("DATABASE_CONN_MAX_AGE", 0 if DEBUG else 600)

DATABASES = {
    "default": dj_database_url.parse(
        normalize_database_url(DATABASE_URL),
        conn_max_age=DATABASE_CONN_MAX_AGE,
        ssl_require=DATABASE_SSL_REQUIRE,
    )
}

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

SUPABASE_STORAGE_BUCKET = env("SUPABASE_STORAGE_BUCKET", "media")
AWS_ACCESS_KEY_ID = env("SUPABASE_STORAGE_ACCESS_KEY", "supabase")
AWS_SECRET_ACCESS_KEY = env(
    "SUPABASE_STORAGE_SECRET_KEY", env("SUPABASE_SERVICE_ROLE_KEY", SUPABASE_ANON_KEY)
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
MEDIA_URL = f"{SUPABASE_URL}/storage/v1/object/public/{SUPABASE_STORAGE_BUCKET}/"

DEFAULT_CORS_ALLOWED_ORIGINS = [
    "https://goklinik.com",
    "https://www.goklinik.com",
    "http://localhost:3000",
    "http://localhost:5173",
    "http://127.0.0.1:5173",
    "capacitor://localhost",
]
CORS_ALLOWED_ORIGINS = sorted(
    set(DEFAULT_CORS_ALLOWED_ORIGINS + env_list("CORS_ALLOWED_ORIGINS", []))
)
CORS_ALLOW_CREDENTIALS = True
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
    "PAGE_SIZE": 25,
}

from datetime import timedelta

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
TEAM_INVITE_LOGIN_PATH = env("TEAM_INVITE_LOGIN_PATH", "/login")
FIREBASE_CREDENTIALS_PATH = env("FIREBASE_CREDENTIALS_PATH", "")

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
