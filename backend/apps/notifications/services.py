from __future__ import annotations

import logging
import re
import unicodedata
from datetime import date, datetime, time, timedelta
import threading
from typing import Any

from django.conf import settings
from django.utils import timezone

from apps.appointments.models import Appointment
from apps.post_op.models import PostOpJourney
from apps.users.models import GoKlinikUser

from .models import (
    Notification,
    NotificationLog,
    NotificationTemplate,
    NotificationToken,
    NotificationWorkflow,
    ScheduledNotification,
)

logger = logging.getLogger(__name__)

TEMPLATE_VARIABLE_PATTERN = re.compile(r"{{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*}}")
OFFSET_PATTERN = re.compile(r"^\s*(\d+)\s*([mhd])\s*$", re.IGNORECASE)

DEFAULT_TEMPLATES: dict[str, dict[str, str]] = {
    "appointment_confirmation": {
        "title": "Consulta registrada",
        "body": "Olá {{name}}, sua consulta está prevista para {{date}} às {{time}} ({{procedure}}).",
    },
    "appointment_reminder_24h": {
        "title": "Lembrete de consulta",
        "body": "Olá {{name}}, lembramos da sua consulta em {{date}} às {{time}} para {{procedure}}.",
    },
    "postop_daily_alert": {
        "title": "Acompanhamento pós-operatório",
        "body": "Olá {{name}}, registre o check-in do dia {{day}} da sua jornada.",
    },
    "manual_push_campaign": {
        "title": "Mensagem da clínica",
        "body": "Olá {{name}}, {{message}}",
    },
}

DEFAULT_WORKFLOW_TRIGGER_OFFSETS = {
    NotificationWorkflow.TriggerTypeChoices.APPOINTMENT_CREATED: "",
    NotificationWorkflow.TriggerTypeChoices.REMINDER_BEFORE: "24h",
    NotificationWorkflow.TriggerTypeChoices.POST_OP_FOLLOWUP: "7d",
}

INVALID_TOKEN_ERROR_MARKERS = (
    "unregistered",
    "registration-token-not-registered",
    "invalid registration token",
    "registration token is not a valid",
    "requested entity was not found",
    "invalidargument",
)
CAMPAIGN_APPOINTMENT_VARIABLES = {"date", "time", "procedure"}
CAMPAIGN_VARIABLE_FALLBACKS = {
    "date": "data a confirmar",
    "time": "horário a confirmar",
    "procedure": "procedimento a confirmar",
}
APPOINTMENT_TYPE_FRIENDLY_LABELS = {
    Appointment.AppointmentTypeChoices.FIRST_VISIT: "Primeira consulta",
    Appointment.AppointmentTypeChoices.RETURN: "Retorno",
    Appointment.AppointmentTypeChoices.SURGERY: "Cirurgia",
    Appointment.AppointmentTypeChoices.POST_OP_7D: "Pós-operatório (7 dias)",
    Appointment.AppointmentTypeChoices.POST_OP_30D: "Pós-operatório (30 dias)",
    Appointment.AppointmentTypeChoices.POST_OP_90D: "Pós-operatório (90 dias)",
}


def render_notification_template(template_text: str, context: dict[str, Any] | None = None) -> str:
    payload = context or {}

    def _replace(match: re.Match[str]) -> str:
        key = match.group(1)
        value = payload.get(key, "")
        return str(value)

    return TEMPLATE_VARIABLE_PATTERN.sub(_replace, template_text or "").strip()


def _normalize_data_payload(data_extra: dict[str, Any] | None) -> dict[str, str]:
    if not data_extra:
        return {}
    return {
        str(key): str(value)
        for key, value in data_extra.items()
        if value is not None
    }


def _is_invalid_token_error(exc: Exception) -> bool:
    class_name = exc.__class__.__name__.lower()
    message = str(exc).lower()
    if "unregistered" in class_name or "invalid" in class_name:
        return True
    return any(marker in message for marker in INVALID_TOKEN_ERROR_MARKERS)


def enviar_notificacao_push(
    tokens: list[str],
    titulo: str,
    corpo: str,
    data_extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    unique_tokens: list[str] = []
    seen: set[str] = set()
    for token in tokens:
        normalized = (token or "").strip()
        if not normalized or normalized in seen:
            continue
        unique_tokens.append(normalized)
        seen.add(normalized)

    if not unique_tokens:
        return {
            "sent_count": 0,
            "failed_count": 0,
            "invalid_tokens": [],
            "errors": {},
        }

    messaging = NotificationService._get_firebase_messaging()
    data_payload = _normalize_data_payload(data_extra)
    sent_count = 0
    failed_count = 0
    invalid_tokens: list[str] = []
    errors: dict[str, str] = {}

    if not messaging:
        error_message = "Firebase messaging unavailable."
        return {
            "sent_count": 0,
            "failed_count": len(unique_tokens),
            "invalid_tokens": [],
            "errors": {token: error_message for token in unique_tokens},
        }

    for token in unique_tokens:
        try:
            message = messaging.Message(
                token=token,
                notification=messaging.Notification(title=titulo, body=corpo),
                data=data_payload,
            )
            messaging.send(message)
            sent_count += 1
        except Exception as exc:  # noqa: BLE001
            failed_count += 1
            errors[token] = str(exc)
            if _is_invalid_token_error(exc):
                invalid_tokens.append(token)

    if invalid_tokens:
        NotificationToken.objects.filter(
            device_token__in=invalid_tokens,
            is_active=True,
        ).update(is_active=False)

    return {
        "sent_count": sent_count,
        "failed_count": failed_count,
        "invalid_tokens": invalid_tokens,
        "errors": errors,
    }


class NotificationService:
    _firebase_messaging_client = None
    _firebase_init_attempted = False
    _firebase_lock = threading.Lock()

    @classmethod
    def _firebase_credentials_from_env(cls) -> dict[str, str] | None:
        project_id = (getattr(settings, "FIREBASE_PROJECT_ID", "") or "").strip()
        client_email = (getattr(settings, "FIREBASE_CLIENT_EMAIL", "") or "").strip()
        private_key = (getattr(settings, "FIREBASE_PRIVATE_KEY", "") or "")
        private_key = private_key.replace("\\n", "\n").strip()

        missing: list[str] = []
        if not project_id:
            missing.append("FIREBASE_PROJECT_ID")
        if not client_email:
            missing.append("FIREBASE_CLIENT_EMAIL")
        if not private_key:
            missing.append("FIREBASE_PRIVATE_KEY")

        if missing:
            logger.error(
                "Firebase env credentials are missing: %s",
                ", ".join(missing),
            )
            return None

        return {
            "type": "service_account",
            "project_id": project_id,
            "client_email": client_email,
            "private_key": private_key,
            "token_uri": "https://oauth2.googleapis.com/token",
        }

    @classmethod
    def _get_firebase_messaging(cls):
        if cls._firebase_messaging_client is not None:
            return cls._firebase_messaging_client
        if cls._firebase_init_attempted:
            return None

        with cls._firebase_lock:
            if cls._firebase_messaging_client is not None:
                return cls._firebase_messaging_client
            if cls._firebase_init_attempted:
                return None

            cls._firebase_init_attempted = True

        try:
            import firebase_admin
            from firebase_admin import credentials, messaging
        except Exception as exc:  # noqa: BLE001
            logger.warning("Firebase SDK unavailable: %s", exc)
            return None

        if firebase_admin._apps:
            cls._firebase_messaging_client = messaging
            return cls._firebase_messaging_client

        credential_payload = cls._firebase_credentials_from_env()
        if not credential_payload:
            return None

        try:
            cred = credentials.Certificate(credential_payload)
            firebase_admin.initialize_app(cred)
            cls._firebase_messaging_client = messaging
            return cls._firebase_messaging_client
        except Exception as exc:  # noqa: BLE001
            logger.exception("Firebase init failed: %s", exc)
            return None

    @staticmethod
    def _friendly_appointment_type_label(appointment_type: str) -> str:
        normalized = (appointment_type or "").strip().lower()
        if normalized in APPOINTMENT_TYPE_FRIENDLY_LABELS:
            return APPOINTMENT_TYPE_FRIENDLY_LABELS[normalized]

        if not normalized:
            return "Procedimento"
        return normalized.replace("_", " ").replace("-", " ").strip().capitalize()

    @staticmethod
    def _normalize_human_key(value: str) -> str:
        normalized = unicodedata.normalize("NFKD", value or "")
        ascii_value = normalized.encode("ascii", "ignore").decode("ascii")
        return re.sub(r"[^a-z0-9]+", " ", ascii_value.lower()).strip()

    @classmethod
    def _friendly_procedure_label(
        cls,
        *,
        procedure: str = "",
        appointment_type: str = "",
    ) -> str:
        raw_value = (procedure or "").strip()
        normalized = cls._normalize_human_key(raw_value)
        alias_labels = {
            "post op 7d": "Pós-operatório (7 dias)",
            "post op 30d": "Pós-operatório (30 dias)",
            "post op 90d": "Pós-operatório (90 dias)",
            "postop 7d": "Pós-operatório (7 dias)",
            "postop 30d": "Pós-operatório (30 dias)",
            "postop 90d": "Pós-operatório (90 dias)",
            "post op 7 dias": "Pós-operatório (7 dias)",
            "post op 30 dias": "Pós-operatório (30 dias)",
            "post op 90 dias": "Pós-operatório (90 dias)",
            "first visit": "Primeira consulta",
            "return": "Retorno",
            "surgery": "Cirurgia",
        }
        if normalized in alias_labels:
            return alias_labels[normalized]

        compact = normalized.replace(" ", "")
        if compact.startswith("postop") or compact.startswith("posop"):
            days_match = re.search(r"(\d{1,3})\s*d", normalized)
            if days_match:
                days = int(days_match.group(1))
                day_label = "dia" if days == 1 else "dias"
                return f"Pós-operatório ({days} {day_label})"
            return "Pós-operatório"

        if raw_value:
            return raw_value
        return cls._friendly_appointment_type_label(appointment_type)

    @staticmethod
    def _friendly_name(value: Any) -> str:
        name = str(value or "").strip()
        return name or "Paciente"

    @staticmethod
    def _friendly_date(value: Any) -> str:
        if isinstance(value, datetime):
            return value.strftime("%d/%m/%Y")
        if isinstance(value, date):
            return value.strftime("%d/%m/%Y")

        raw = str(value or "").strip()
        if not raw:
            return ""
        normalized = raw.replace("Z", "+00:00")
        try:
            parsed = datetime.fromisoformat(normalized)
            return parsed.strftime("%d/%m/%Y")
        except ValueError:
            pass
        for pattern in ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y"):
            try:
                parsed = datetime.strptime(raw, pattern)
                return parsed.strftime("%d/%m/%Y")
            except ValueError:
                continue
        return raw

    @staticmethod
    def _friendly_time(value: Any) -> str:
        if isinstance(value, datetime):
            return value.strftime("%H:%M")
        if isinstance(value, time):
            return value.strftime("%H:%M")

        raw = str(value or "").strip()
        if not raw:
            return ""
        normalized = raw.replace("Z", "+00:00")
        try:
            parsed = datetime.fromisoformat(normalized)
            return parsed.strftime("%H:%M")
        except ValueError:
            pass
        for pattern in ("%H:%M:%S", "%H:%M"):
            try:
                parsed = datetime.strptime(raw, pattern)
                return parsed.strftime("%H:%M")
            except ValueError:
                continue
        return raw

    @classmethod
    def _normalize_template_context(
        cls,
        context: dict[str, Any],
        template_variables: set[str] | None = None,
    ) -> dict[str, Any]:
        variables = template_variables or set(context.keys())
        normalized = dict(context)
        for variable in variables:
            if variable == "name":
                normalized[variable] = cls._friendly_name(normalized.get(variable))
            elif variable == "date":
                normalized[variable] = cls._friendly_date(normalized.get(variable))
            elif variable == "time":
                normalized[variable] = cls._friendly_time(normalized.get(variable))
            elif variable == "procedure":
                normalized[variable] = cls._friendly_procedure_label(
                    procedure=str(normalized.get(variable) or ""),
                )
            elif variable == "day":
                try:
                    normalized[variable] = str(int(normalized.get(variable)))
                except (TypeError, ValueError):
                    normalized[variable] = str(normalized.get(variable) or "").strip()
        return normalized

    @classmethod
    def _appointment_context(cls, appointment: Appointment) -> dict[str, Any]:
        procedure = ""
        if appointment.specialty:
            procedure = (appointment.specialty.specialty_name or "").strip()
        procedure = cls._friendly_procedure_label(
            procedure=procedure,
            appointment_type=appointment.appointment_type,
        )
        return {
            "name": cls._friendly_name(appointment.patient.full_name),
            "date": cls._friendly_date(appointment.appointment_date),
            "time": cls._friendly_time(appointment.appointment_time),
            "procedure": procedure,
        }

    @staticmethod
    def _template_variables(*templates: str) -> set[str]:
        variables: set[str] = set()
        for template in templates:
            if not template:
                continue
            variables.update(match.group(1) for match in TEMPLATE_VARIABLE_PATTERN.finditer(template))
        return variables

    @staticmethod
    def _has_context_value(value: Any) -> bool:
        if value is None:
            return False
        if isinstance(value, str):
            return bool(value.strip())
        return True

    @classmethod
    def _recipient_appointment_context(cls, recipient: GoKlinikUser) -> dict[str, str]:
        today = timezone.localdate()
        non_eligible_upcoming_statuses = [
            Appointment.StatusChoices.CANCELLED,
            Appointment.StatusChoices.RESCHEDULED,
            Appointment.StatusChoices.COMPLETED,
        ]
        non_eligible_history_statuses = [
            Appointment.StatusChoices.CANCELLED,
            Appointment.StatusChoices.RESCHEDULED,
        ]

        appointment = (
            Appointment.objects.select_related("patient", "specialty")
            .filter(patient=recipient, appointment_date__gte=today)
            .exclude(status__in=non_eligible_upcoming_statuses)
            .order_by("appointment_date", "appointment_time")
            .first()
        )
        if not appointment:
            appointment = (
                Appointment.objects.select_related("patient", "specialty")
                .filter(patient=recipient)
                .exclude(status__in=non_eligible_history_statuses)
                .order_by("-appointment_date", "-appointment_time")
                .first()
            )
        if not appointment:
            return {}

        appointment_context = cls._appointment_context(appointment)
        return {
            "date": appointment_context.get("date", ""),
            "time": appointment_context.get("time", ""),
            "procedure": appointment_context.get("procedure", ""),
        }

    @staticmethod
    def _resolve_template(
        *,
        code: str,
        fallback_title: str,
        fallback_body: str,
        tenant_id=None,
    ) -> tuple[str, str]:
        template = None
        active_templates = NotificationTemplate.objects.filter(
            code=code,
            is_active=True,
        )
        if tenant_id:
            template = active_templates.filter(tenant_id=tenant_id).first()
            if not template:
                template = active_templates.filter(tenant__isnull=True).first()
        else:
            template = active_templates.filter(tenant__isnull=True).first() or active_templates.first()
        if template:
            return template.title_template, template.body_template

        default_template = DEFAULT_TEMPLATES.get(code)
        if default_template:
            return default_template["title"], default_template["body"]
        return fallback_title, fallback_body

    @classmethod
    def get_template_content(
        cls,
        *,
        code: str,
        fallback_title: str,
        fallback_body: str,
        tenant_id=None,
    ) -> tuple[str, str]:
        return cls._resolve_template(
            code=code,
            fallback_title=fallback_title,
            fallback_body=fallback_body,
            tenant_id=tenant_id,
        )

    @staticmethod
    def _is_rate_limited(user_id: str) -> bool:
        limit = int(getattr(settings, "PUSH_MAX_PER_USER_PER_HOUR", 20) or 20)
        if limit <= 0:
            return False

        since = timezone.now() - timedelta(hours=1)
        total = NotificationLog.objects.filter(
            user_id=user_id,
            channel=NotificationLog.ChannelChoices.PUSH,
            status=NotificationLog.StatusChoices.SENT,
            created_at__gte=since,
        ).count()
        return total >= limit

    @staticmethod
    def create_in_app_notification(
        *,
        recipient: GoKlinikUser,
        title: str,
        body: str,
        notification_type: str = Notification.NotificationTypeChoices.SYSTEM,
        related_object_id=None,
        sent_at: datetime | None = None,
    ) -> Notification:
        return Notification.objects.create(
            tenant_id=recipient.tenant_id,
            recipient=recipient,
            title=title,
            body=body,
            notification_type=notification_type,
            related_object_id=related_object_id,
            sent_at=sent_at or timezone.now(),
        )

    @classmethod
    def notify_clinic_masters_in_app(
        cls,
        *,
        tenant_id,
        title: str,
        body: str,
        related_object_id=None,
        notification_type: str = Notification.NotificationTypeChoices.SYSTEM,
    ) -> int:
        if not tenant_id:
            return 0

        recipients = GoKlinikUser.objects.filter(
            tenant_id=tenant_id,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
            is_active=True,
        )

        created_count = 0
        for recipient in recipients:
            try:
                cls.create_in_app_notification(
                    recipient=recipient,
                    title=title,
                    body=body,
                    notification_type=notification_type,
                    related_object_id=related_object_id,
                )
                created_count += 1
            except Exception:  # noqa: BLE001
                logger.exception(
                    "Unable to persist clinic-master in-app notification recipient=%s tenant=%s",
                    recipient.id,
                    tenant_id,
                )
        return created_count

    @classmethod
    def send_push_to_user(
        cls,
        *,
        user: GoKlinikUser,
        title: str,
        body: str,
        data_extra: dict[str, Any] | None = None,
        event_code: str = "",
        segment: str = "",
        idempotency_key: str | None = None,
        notification_type: str = Notification.NotificationTypeChoices.SYSTEM,
        related_object_id=None,
        create_in_app_notification: bool = True,
    ) -> NotificationLog:
        if idempotency_key:
            existing = NotificationLog.objects.filter(
                user_id=user.id,
                idempotency_key=idempotency_key,
                status=NotificationLog.StatusChoices.SENT,
            ).first()
            if existing:
                return existing

        if cls._is_rate_limited(str(user.id)):
            return NotificationLog.objects.create(
                tenant_id=user.tenant_id,
                user=user,
                title=title,
                body=body,
                channel=NotificationLog.ChannelChoices.PUSH,
                status=NotificationLog.StatusChoices.RATE_LIMITED,
                event_code=event_code,
                segment=segment,
                idempotency_key=idempotency_key,
                data_extra=data_extra or {},
                error_message="Push suppressed by anti-spam rule.",
            )

        tokens = list(
            NotificationToken.objects.filter(
                user_id=user.id,
                is_active=True,
            ).values_list("device_token", flat=True),
        )
        try:
            push_result = enviar_notificacao_push(
                tokens=tokens,
                titulo=title,
                corpo=body,
                data_extra=data_extra or {},
            )
        except Exception as exc:  # noqa: BLE001
            logger.exception(
                "Unexpected push send error for user=%s event=%s",
                user.id,
                event_code,
            )
            push_result = {
                "sent_count": 0,
                "failed_count": len(tokens),
                "invalid_tokens": [],
                "errors": {"__all__": str(exc)},
            }

        if push_result["sent_count"] > 0:
            status_value = NotificationLog.StatusChoices.SENT
            error_message = ""
        elif not tokens:
            status_value = NotificationLog.StatusChoices.ERROR
            error_message = "No active push tokens for user."
        else:
            status_value = NotificationLog.StatusChoices.ERROR
            error_message = next(iter(push_result["errors"].values()), "Push send failed.")

        log = NotificationLog.objects.create(
            tenant_id=user.tenant_id,
            user=user,
            title=title,
            body=body,
            channel=NotificationLog.ChannelChoices.PUSH,
            status=status_value,
            event_code=event_code,
            segment=segment,
            idempotency_key=idempotency_key,
            data_extra=data_extra or {},
            error_message=error_message,
        )

        if create_in_app_notification and status_value == NotificationLog.StatusChoices.SENT:
            try:
                cls.create_in_app_notification(
                    recipient=user,
                    title=title,
                    body=body,
                    notification_type=notification_type,
                    related_object_id=related_object_id,
                )
            except Exception:  # noqa: BLE001
                logger.exception(
                    "Unable to persist in-app notification for user=%s event=%s",
                    user.id,
                    event_code,
                )

        return log

    @classmethod
    def send_push_campaign(
        cls,
        *,
        recipients: list[GoKlinikUser],
        title_template: str,
        body_template: str,
        context: dict[str, Any] | None = None,
        segment: str,
        event_code: str,
        data_extra: dict[str, Any] | None = None,
        create_in_app_notification: bool = True,
        idempotency_prefix: str | None = None,
    ) -> dict[str, int]:
        summary = {
            "total_recipients": len(recipients),
            "sent": 0,
            "error": 0,
            "skipped": 0,
            "rate_limited": 0,
        }
        base_context = context or {}
        required_variables = cls._template_variables(title_template, body_template)
        needs_appointment_context = bool(required_variables.intersection(CAMPAIGN_APPOINTMENT_VARIABLES))

        for recipient in recipients:
            payload_context = {
                "name": recipient.full_name,
                **base_context,
            }
            if needs_appointment_context:
                missing_appointment_variables = [
                    variable
                    for variable in CAMPAIGN_APPOINTMENT_VARIABLES
                    if variable in required_variables and not cls._has_context_value(payload_context.get(variable))
                ]
                if missing_appointment_variables:
                    appointment_context = cls._recipient_appointment_context(recipient)
                    for variable in missing_appointment_variables:
                        value = appointment_context.get(variable)
                        if cls._has_context_value(value):
                            payload_context[variable] = value
            for variable in required_variables:
                if (
                    variable in CAMPAIGN_VARIABLE_FALLBACKS
                    and not cls._has_context_value(payload_context.get(variable))
                ):
                    payload_context[variable] = CAMPAIGN_VARIABLE_FALLBACKS[variable]
            payload_context = cls._normalize_template_context(payload_context, required_variables)
            title = render_notification_template(title_template, payload_context)
            body = render_notification_template(body_template, payload_context)

            idempotency_key = None
            if idempotency_prefix:
                idempotency_key = f"{idempotency_prefix}:{recipient.id}"

            try:
                log = cls.send_push_to_user(
                    user=recipient,
                    title=title,
                    body=body,
                    data_extra=data_extra or {},
                    event_code=event_code,
                    segment=segment,
                    idempotency_key=idempotency_key,
                    notification_type=Notification.NotificationTypeChoices.PROMOTION,
                    create_in_app_notification=create_in_app_notification,
                )
                if log.status == NotificationLog.StatusChoices.SENT:
                    summary["sent"] += 1
                elif log.status == NotificationLog.StatusChoices.RATE_LIMITED:
                    summary["rate_limited"] += 1
                elif log.status == NotificationLog.StatusChoices.SKIPPED:
                    summary["skipped"] += 1
                else:
                    summary["error"] += 1
            except Exception as exc:  # noqa: BLE001
                summary["error"] += 1
                logger.exception(
                    "Campaign push failed for user=%s event=%s segment=%s",
                    recipient.id,
                    event_code,
                    segment,
                )
                try:
                    NotificationLog.objects.create(
                        tenant_id=recipient.tenant_id,
                        user=recipient,
                        title=title,
                        body=body,
                        channel=NotificationLog.ChannelChoices.PUSH,
                        status=NotificationLog.StatusChoices.ERROR,
                        event_code=event_code,
                        segment=segment,
                        idempotency_key=idempotency_key,
                        data_extra=data_extra or {},
                        error_message=str(exc),
                    )
                except Exception:  # noqa: BLE001
                    logger.exception("Unable to persist campaign failure log for user=%s", recipient.id)

        return summary

    @staticmethod
    def resolve_recipients_for_segment(
        *,
        tenant_id,
        segment: str,
        specialty_id=None,
        require_active_tokens: bool = False,
    ):
        queryset = GoKlinikUser.objects.filter(
            role=GoKlinikUser.RoleChoices.PATIENT,
            tenant_id=tenant_id,
            is_active=True,
        )
        normalized_segment = (segment or "all_patients").strip().lower()
        today = timezone.localdate()

        if normalized_segment == "future_appointments":
            queryset = queryset.filter(
                patient__appointments__appointment_date__gte=today,
            ).exclude(
                patient__appointments__status__in=[
                    Appointment.StatusChoices.CANCELLED,
                    Appointment.StatusChoices.COMPLETED,
                    Appointment.StatusChoices.RESCHEDULED,
                ]
            )
        elif normalized_segment == "inactive_patients":
            queryset = queryset.filter(patient__status="inactive")

        if specialty_id:
            queryset = queryset.filter(patient__specialty_id=specialty_id)
        if require_active_tokens:
            queryset = queryset.filter(
                notification_tokens__is_active=True,
            ).exclude(
                notification_tokens__device_token__isnull=True,
            ).exclude(
                notification_tokens__device_token__exact="",
            )
        return queryset.distinct().order_by("first_name", "last_name", "email")

    @classmethod
    def send_push(
        cls,
        user_id,
        title,
        body,
        data=None,
    ) -> int:
        user = GoKlinikUser.objects.filter(id=user_id).first()
        if not user:
            return 0

        log = cls.send_push_to_user(
            user=user,
            title=title,
            body=body,
            data_extra=data or {},
            event_code="direct_push",
            create_in_app_notification=False,
        )
        return 1 if log.status == NotificationLog.StatusChoices.SENT else 0

    @classmethod
    def send_appointment_confirmation(cls, appointment_id: str):
        appointment = (
            Appointment.objects.select_related("patient", "tenant", "specialty", "professional")
            .filter(id=appointment_id)
            .first()
        )
        if not appointment:
            return "appointment-not-found"

        title_template, body_template = cls._resolve_template(
            code="appointment_confirmation",
            fallback_title="Consulta registrada",
            fallback_body=(
                "Olá {{name}}, sua consulta está prevista para {{date}} às {{time}} ({{procedure}})."
            ),
            tenant_id=appointment.tenant_id,
        )
        context = cls._appointment_context(appointment)
        title = render_notification_template(title_template, context)
        body = render_notification_template(body_template, context)

        log = cls.send_push_to_user(
            user=appointment.patient,
            title=title,
            body=body,
            data_extra={
                "appointment_id": str(appointment.id),
                "event": "appointment_confirmation",
            },
            event_code="appointment_confirmation",
            idempotency_key=f"appointment_confirmation:{appointment.id}",
            notification_type=Notification.NotificationTypeChoices.SYSTEM,
            related_object_id=appointment.id,
        )
        return log.status

    @classmethod
    def send_appointment_reminder(cls, appointment_id):
        appointment = (
            Appointment.objects.select_related("patient", "tenant", "specialty", "professional")
            .filter(id=appointment_id)
            .first()
        )
        if not appointment:
            return "appointment-not-found"
        if appointment.status in {
            Appointment.StatusChoices.CANCELLED,
            Appointment.StatusChoices.RESCHEDULED,
            Appointment.StatusChoices.COMPLETED,
        }:
            return "appointment-not-eligible"

        title_template, body_template = cls._resolve_template(
            code="appointment_reminder_24h",
            fallback_title="Lembrete de consulta",
            fallback_body=(
                "Olá {{name}}, lembramos da sua consulta em {{date}} às {{time}} para {{procedure}}."
            ),
            tenant_id=appointment.tenant_id,
        )
        context = cls._appointment_context(appointment)
        title = render_notification_template(title_template, context)
        body = render_notification_template(body_template, context)

        log = cls.send_push_to_user(
            user=appointment.patient,
            title=title,
            body=body,
            data_extra={
                "appointment_id": str(appointment.id),
                "event": "appointment_reminder_24h",
            },
            event_code="appointment_reminder_24h",
            idempotency_key=f"appointment_reminder_24h:{appointment.id}",
            notification_type=Notification.NotificationTypeChoices.APPOINTMENT_REMINDER,
            related_object_id=appointment.id,
        )
        return log.status

    @classmethod
    def send_postop_daily_alert(cls, journey_id, day_number):
        journey = (
            PostOpJourney.objects.select_related("patient", "patient__tenant")
            .filter(id=journey_id)
            .first()
        )
        if not journey:
            return "journey-not-found"

        title_template, body_template = cls._resolve_template(
            code="postop_daily_alert",
            fallback_title=f"Pós-op Dia {day_number}",
            fallback_body="Olá {{name}}, registre o check-in do dia {{day}} da sua jornada.",
            tenant_id=journey.patient.tenant_id,
        )
        context = {
            "name": journey.patient.full_name,
            "day": day_number,
        }
        title = render_notification_template(title_template, context)
        body = render_notification_template(body_template, context)

        log = cls.send_push_to_user(
            user=journey.patient,
            title=title,
            body=body,
            data_extra={
                "journey_id": str(journey.id),
                "event": "postop_daily_alert",
                "day": day_number,
            },
            event_code="postop_daily_alert",
            idempotency_key=f"postop_daily_alert:{journey.id}:{day_number}",
            notification_type=Notification.NotificationTypeChoices.POSTOP_ALERT,
            related_object_id=journey.id,
        )
        return log.status

    @staticmethod
    def mark_as_read(notification_id, user_id):
        notification = Notification.objects.filter(id=notification_id, recipient_id=user_id).first()
        if not notification:
            return None
        notification.is_read = True
        notification.save(update_fields=["is_read"])
        return notification


class NotificationAutomationService:
    @classmethod
    def ensure_default_workflows_for_tenant(cls, tenant_id) -> None:
        if not tenant_id:
            return
        if NotificationWorkflow.objects.filter(tenant_id=tenant_id).exists():
            return

        reminder_offset_hours = int(getattr(settings, "APPOINTMENT_REMINDER_HOURS_BEFORE", 24) or 24)
        if reminder_offset_hours < 0:
            reminder_offset_hours = 24

        NotificationWorkflow.objects.bulk_create(
            [
                NotificationWorkflow(
                    tenant_id=tenant_id,
                    name="Confirmação de consulta",
                    trigger_type=NotificationWorkflow.TriggerTypeChoices.APPOINTMENT_CREATED,
                    trigger_offset="",
                    is_active=True,
                ),
                NotificationWorkflow(
                    tenant_id=tenant_id,
                    name=f"Lembrete {reminder_offset_hours}h antes",
                    trigger_type=NotificationWorkflow.TriggerTypeChoices.REMINDER_BEFORE,
                    trigger_offset=f"{reminder_offset_hours}h",
                    is_active=True,
                ),
                NotificationWorkflow(
                    tenant_id=tenant_id,
                    name="Follow-up pós-operatório",
                    trigger_type=NotificationWorkflow.TriggerTypeChoices.POST_OP_FOLLOWUP,
                    trigger_offset="7d",
                    is_active=False,
                ),
            ]
        )

    @staticmethod
    def _to_aware_datetime(value: datetime) -> datetime:
        if timezone.is_aware(value):
            return value
        return timezone.make_aware(value, timezone.get_current_timezone())

    @classmethod
    def _parse_offset_to_timedelta(
        cls,
        raw_offset: str,
        *,
        fallback: str = "",
    ) -> timedelta:
        source = (raw_offset or fallback or "").strip().lower()
        if not source:
            return timedelta(0)

        match = OFFSET_PATTERN.match(source)
        if not match:
            raise ValueError(f"Invalid trigger_offset '{raw_offset}'. Expected formats like 24h, 7d or 30m.")

        amount = int(match.group(1))
        unit = match.group(2).lower()
        if unit == "m":
            return timedelta(minutes=amount)
        if unit == "h":
            return timedelta(hours=amount)
        return timedelta(days=amount)

    @classmethod
    def _workflow_offset(cls, workflow: NotificationWorkflow) -> timedelta:
        fallback = DEFAULT_WORKFLOW_TRIGGER_OFFSETS.get(workflow.trigger_type, "")
        return cls._parse_offset_to_timedelta(workflow.trigger_offset, fallback=fallback)

    @staticmethod
    def _appointment_datetime(appointment: Appointment) -> datetime:
        dt = datetime.combine(appointment.appointment_date, appointment.appointment_time)
        return NotificationAutomationService._to_aware_datetime(dt)

    @staticmethod
    def _workflow_context_for_appointment(appointment: Appointment) -> dict[str, Any]:
        return NotificationService._appointment_context(appointment)

    @staticmethod
    def _workflow_template_for_trigger(trigger_type: str) -> tuple[str, str, str]:
        if trigger_type == NotificationWorkflow.TriggerTypeChoices.REMINDER_BEFORE:
            return (
                "appointment_reminder_24h",
                "Lembrete de consulta",
                "Olá {{name}}, lembramos da sua consulta em {{date}} às {{time}} para {{procedure}}.",
            )
        if trigger_type == NotificationWorkflow.TriggerTypeChoices.POST_OP_FOLLOWUP:
            return (
                "postop_daily_alert",
                "Acompanhamento pós-operatório",
                "Olá {{name}}, registre seu acompanhamento pós-operatório.",
            )
        return (
            "appointment_confirmation",
            "Consulta registrada",
            "Olá {{name}}, sua consulta está prevista para {{date}} às {{time}} ({{procedure}}).",
        )

    @classmethod
    def _render_workflow_message(
        cls,
        *,
        workflow: NotificationWorkflow,
        appointment: Appointment,
    ) -> tuple[str, str]:
        context = cls._workflow_context_for_appointment(appointment)
        if workflow.template_id:
            title_template = workflow.template.title_template
            body_template = workflow.template.body_template
        else:
            code, fallback_title, fallback_body = cls._workflow_template_for_trigger(workflow.trigger_type)
            title_template, body_template = NotificationService.get_template_content(
                code=code,
                fallback_title=fallback_title,
                fallback_body=fallback_body,
                tenant_id=appointment.tenant_id,
            )

        title = render_notification_template(title_template, context)
        body = render_notification_template(body_template, context)
        return title, body

    @classmethod
    def _workflow_idempotency_key(
        cls,
        *,
        workflow: NotificationWorkflow,
        appointment: Appointment,
    ) -> str:
        return (
            f"workflow:{workflow.id}:{workflow.trigger_type}:{appointment.id}:"
            f"{appointment.appointment_date.isoformat()}:{appointment.appointment_time.isoformat()}"
        )

    @classmethod
    def execute_workflow_for_appointment(
        cls,
        *,
        workflow_id: str,
        appointment_id: str,
    ) -> str:
        workflow = (
            NotificationWorkflow.objects.select_related("template")
            .filter(id=workflow_id)
            .first()
        )
        if not workflow:
            return "workflow-not-found"
        if not workflow.is_active:
            return "workflow-inactive"

        appointment = (
            Appointment.objects.select_related("patient", "specialty", "professional", "tenant")
            .filter(id=appointment_id)
            .first()
        )
        if not appointment:
            return "appointment-not-found"

        title, body = cls._render_workflow_message(workflow=workflow, appointment=appointment)

        log = NotificationService.send_push_to_user(
            user=appointment.patient,
            title=title,
            body=body,
            data_extra={
                "workflow_id": str(workflow.id),
                "appointment_id": str(appointment.id),
                "event": workflow.trigger_type,
            },
            event_code=workflow.trigger_type,
            segment="workflow",
            idempotency_key=cls._workflow_idempotency_key(
                workflow=workflow,
                appointment=appointment,
            ),
            notification_type=Notification.NotificationTypeChoices.SYSTEM,
            related_object_id=appointment.id,
        )
        return log.status

    @classmethod
    def _active_workflows(cls, *, tenant_id, trigger_type: str):
        cls.ensure_default_workflows_for_tenant(tenant_id)
        return NotificationWorkflow.objects.select_related("template").filter(
            tenant_id=tenant_id,
            is_active=True,
            trigger_type=trigger_type,
        )

    @classmethod
    def _enqueue_workflow_execution(
        cls,
        *,
        workflow_id: str,
        appointment_id: str,
        eta: datetime | None = None,
    ) -> None:
        from .tasks import execute_workflow_for_appointment_task

        if eta and eta > timezone.now():
            execute_workflow_for_appointment_task.apply_async(
                kwargs={"workflow_id": str(workflow_id), "appointment_id": str(appointment_id)},
                eta=eta,
            )
            return
        execute_workflow_for_appointment_task.delay(
            workflow_id=str(workflow_id),
            appointment_id=str(appointment_id),
        )

    @classmethod
    def dispatch_appointment_created_workflows(cls, appointment_id: str) -> int:
        appointment = Appointment.objects.filter(id=appointment_id).first()
        if not appointment:
            return 0
        workflows = cls._active_workflows(
            tenant_id=appointment.tenant_id,
            trigger_type=NotificationWorkflow.TriggerTypeChoices.APPOINTMENT_CREATED,
        )
        count = 0
        for workflow in workflows:
            cls._enqueue_workflow_execution(
                workflow_id=str(workflow.id),
                appointment_id=str(appointment.id),
                eta=None,
            )
            count += 1
        return count

    @classmethod
    def schedule_appointment_reminder_workflows(cls, appointment_id: str) -> int:
        appointment = Appointment.objects.filter(id=appointment_id).first()
        if not appointment:
            return 0
        scheduled_dt = cls._appointment_datetime(appointment)
        count = 0

        workflows = cls._active_workflows(
            tenant_id=appointment.tenant_id,
            trigger_type=NotificationWorkflow.TriggerTypeChoices.REMINDER_BEFORE,
        )
        for workflow in workflows:
            try:
                eta = scheduled_dt - cls._workflow_offset(workflow)
            except ValueError:
                logger.exception("Invalid reminder workflow offset workflow_id=%s", workflow.id)
                continue

            cls._enqueue_workflow_execution(
                workflow_id=str(workflow.id),
                appointment_id=str(appointment.id),
                eta=eta,
            )
            count += 1
        return count

    @classmethod
    def schedule_postop_followup_workflows(cls, appointment_id: str) -> int:
        appointment = Appointment.objects.filter(id=appointment_id).first()
        if not appointment:
            return 0
        base_dt = cls._appointment_datetime(appointment)
        count = 0

        workflows = cls._active_workflows(
            tenant_id=appointment.tenant_id,
            trigger_type=NotificationWorkflow.TriggerTypeChoices.POST_OP_FOLLOWUP,
        )
        for workflow in workflows:
            try:
                eta = base_dt + cls._workflow_offset(workflow)
            except ValueError:
                logger.exception("Invalid postop workflow offset workflow_id=%s", workflow.id)
                continue

            cls._enqueue_workflow_execution(
                workflow_id=str(workflow.id),
                appointment_id=str(appointment.id),
                eta=eta,
            )
            count += 1
        return count

    @classmethod
    def create_scheduled_notification(
        cls,
        *,
        created_by: GoKlinikUser,
        run_at: datetime,
        segment: str,
        title: str = "",
        body: str = "",
        template: NotificationTemplate | None = None,
        template_context: dict[str, Any] | None = None,
        data_extra: dict[str, Any] | None = None,
    ) -> ScheduledNotification:
        run_at = cls._to_aware_datetime(run_at)
        scheduled = ScheduledNotification.objects.create(
            tenant_id=created_by.tenant_id,
            created_by=created_by,
            run_at=run_at,
            segment=segment,
            title=title,
            body=body,
            template=template,
            template_context=template_context or {},
            data_extra=data_extra or {},
            status=ScheduledNotification.StatusChoices.PENDING,
        )

        from .tasks import run_scheduled_notification_task

        try:
            async_result = run_scheduled_notification_task.apply_async(
                kwargs={"scheduled_notification_id": str(scheduled.id)},
                eta=run_at,
            )
            scheduled.celery_task_id = async_result.id or ""
            scheduled.save(update_fields=["celery_task_id", "updated_at"])
        except Exception as exc:  # noqa: BLE001
            logger.exception(
                "Unable to schedule celery task for scheduled_notification=%s",
                scheduled.id,
            )
            scheduled.status = ScheduledNotification.StatusChoices.ERROR
            scheduled.error_message = str(exc)
            scheduled.save(update_fields=["status", "error_message", "updated_at"])
        return scheduled

    @classmethod
    def execute_scheduled_notification(cls, scheduled_notification_id: str) -> dict[str, Any]:
        scheduled = (
            ScheduledNotification.objects.select_related("template", "created_by")
            .filter(id=scheduled_notification_id)
            .first()
        )
        if not scheduled:
            return {"status": "not-found"}
        if scheduled.status == ScheduledNotification.StatusChoices.CANCELED:
            return {"status": "canceled"}
        if scheduled.status == ScheduledNotification.StatusChoices.COMPLETED:
            return {"status": "already-completed", "summary": scheduled.summary}

        scheduled.status = ScheduledNotification.StatusChoices.RUNNING
        scheduled.error_message = ""
        scheduled.save(update_fields=["status", "error_message", "updated_at"])

        try:
            recipients = list(
                NotificationService.resolve_recipients_for_segment(
                    tenant_id=scheduled.tenant_id,
                    segment=scheduled.segment,
                    require_active_tokens=True,
                )
            )
            if scheduled.template_id:
                title_template = scheduled.template.title_template
                body_template = scheduled.template.body_template
            else:
                title_template = scheduled.title or "Mensagem da clínica"
                body_template = scheduled.body or ""

            summary = NotificationService.send_push_campaign(
                recipients=recipients,
                title_template=title_template,
                body_template=body_template,
                context=scheduled.template_context,
                segment=scheduled.segment,
                event_code="manual_scheduled_campaign",
                data_extra={
                    **scheduled.data_extra,
                    "scheduled_notification_id": str(scheduled.id),
                },
                create_in_app_notification=True,
                idempotency_prefix=f"scheduled_campaign:{scheduled.id}",
            )
            scheduled.status = ScheduledNotification.StatusChoices.COMPLETED
            scheduled.summary = summary
            scheduled.processed_at = timezone.now()
            scheduled.save(
                update_fields=[
                    "status",
                    "summary",
                    "processed_at",
                    "updated_at",
                ]
            )
            return {"status": "completed", "summary": summary}
        except Exception as exc:  # noqa: BLE001
            logger.exception(
                "Scheduled notification execution failed id=%s",
                scheduled.id,
            )
            scheduled.status = ScheduledNotification.StatusChoices.ERROR
            scheduled.error_message = str(exc)
            scheduled.processed_at = timezone.now()
            scheduled.save(
                update_fields=[
                    "status",
                    "error_message",
                    "processed_at",
                    "updated_at",
                ]
            )
            return {"status": "error", "error": str(exc)}
