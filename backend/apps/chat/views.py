from __future__ import annotations

import base64
import binascii
import logging
import re
from datetime import timedelta
from decimal import Decimal

from django.db import models
from django.db.models import OuterRef, Subquery
from django.core.files.base import ContentFile
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from config.media_urls import absolute_media_url

from apps.appointments.models import Appointment
from apps.patients.models import Patient
from apps.post_op.models import PostOpJourney
from apps.referrals.models import Referral
from apps.users.models import GoKlinikUser
from apps.users.invite_email import normalize_invite_email_language
from services.storage_paths import build_storage_path
from services.supabase_storage import SupabaseStorageError, upload_file

from .ai_service import AIServiceError, request_chat_completion, resolve_ai_runtime_config
from .models import (
    ChatRoom,
    Message,
    PatientAIConversationControl,
    PatientAIMessage,
    PatientAITypingStatus,
    TenantAIChatSettings,
)
from .serializers import (
    ChatMessageCreateSerializer,
    ChatRoomCreateSerializer,
    ChatRoomListSerializer,
    MessageSerializer,
    PatientAIConversationControlSerializer,
    PatientAIMessageCreateSerializer,
    PatientAIMessageSerializer,
    PatientAITypingUpdateSerializer,
    StaffPatientAIMessageCreateSerializer,
    TenantAIChatSettingsSerializer,
)

logger = logging.getLogger(__name__)

STAFF_ROLES = {
    GoKlinikUser.RoleChoices.CLINIC_MASTER,
    GoKlinikUser.RoleChoices.SURGEON,
    GoKlinikUser.RoleChoices.SECRETARY,
    GoKlinikUser.RoleChoices.NURSE,
}

CHAT_ADMIN_ROLES = {
    GoKlinikUser.RoleChoices.CLINIC_MASTER,
    GoKlinikUser.RoleChoices.SECRETARY,
}

AI_TYPING_TTL_SECONDS = 12


def _is_chat_admin(user: GoKlinikUser) -> bool:
    return user.role in CHAT_ADMIN_ROLES


def _get_or_create_tenant_ai_settings(tenant_id):
    settings, _ = TenantAIChatSettings.objects.get_or_create(tenant_id=tenant_id)
    return settings


def _get_or_create_patient_ai_control(*, tenant_id, patient_id):
    control, _ = PatientAIConversationControl.objects.get_or_create(
        tenant_id=tenant_id,
        patient_id=patient_id,
    )
    return control


def _is_patient_ai_enabled(*, tenant_id, patient_id) -> bool:
    tenant_settings = _get_or_create_tenant_ai_settings(tenant_id)
    if not tenant_settings.ai_enabled:
        return False

    control = (
        PatientAIConversationControl.objects.filter(
            tenant_id=tenant_id,
            patient_id=patient_id,
        )
        .only("force_human")
        .first()
    )
    if control and control.force_human:
        return False
    return True

EMOJI_PATTERN = re.compile(
    "["
    "\U0001F1E6-\U0001F1FF"  # flags
    "\U0001F300-\U0001FAFF"  # symbols and pictographs
    "\U00002700-\U000027BF"  # dingbats
    "\U000024C2-\U0001F251"  # enclosed characters
    "]+",
    flags=re.UNICODE,
)

LANGUAGE_COPY = {
    "en": {
        "base_prompt": "You are the clinic virtual assistant. Reply with empathy and clarity.",
        "security_rules": (
            "SECURITY RULES (MANDATORY): reply only about the authenticated patient. "
            "Never reveal data from other patients. If information is missing, say you do not have it and "
            "guide the patient to contact the clinic."
        ),
        "style_rules": (
            "STYLE RULES (MANDATORY): do not use emojis, emoticons, or decorative symbols. "
            "Use plain and clear text."
        ),
        "context_title": "AUTHENTICATED PATIENT CONTEXT:",
        "name": "Name",
        "email": "Email",
        "phone": "Phone",
        "dob": "Date of birth",
        "main_specialty": "Main specialty",
        "post_op_none": "No active post-op journey.",
        "post_op_active": "Active post-op journey: surgery on {date}, current day D+{day}, procedure: {procedure}.",
        "not_informed": "Not informed",
        "not_defined": "Not defined",
        "referrals": "Referrals made",
        "converted": "Converted referrals",
        "paid_commissions": "Paid commissions",
        "total_paid": "Total paid",
        "next_appointments": "Upcoming appointments",
        "no_upcoming": "No upcoming appointments found.",
        "appointment_type": "Type",
        "appointment_status": "Status",
        "professional": "Professional",
        "location": "Location",
        "err_credits": "Clinic support is temporarily unavailable. Please contact the clinic.",
        "err_key": "Clinic support is not configured correctly at the moment.",
        "err_default": "Clinic support is temporarily unavailable. Please try again shortly.",
    },
    "pt": {
        "base_prompt": "Você é a assistente virtual da clínica. Responda com empatia e objetividade.",
        "security_rules": (
            "REGRAS DE SEGURANÇA (OBRIGATÓRIO): responda apenas sobre o paciente autenticado. "
            "Nunca revele dados de outros pacientes. Se faltar informação, diga que não possui esse dado e "
            "oriente contato com a clínica."
        ),
        "style_rules": (
            "REGRAS DE ESTILO (OBRIGATÓRIO): não use emojis, emoticons ou símbolos decorativos especiais. "
            "Escreva em texto simples e claro."
        ),
        "context_title": "CONTEXTO DO PACIENTE AUTENTICADO:",
        "name": "Nome",
        "email": "E-mail",
        "phone": "Telefone",
        "dob": "Data de nascimento",
        "main_specialty": "Especialidade principal",
        "post_op_none": "Sem jornada pós-operatória ativa.",
        "post_op_active": "Jornada pós-operatória ativa: cirurgia em {date}, dia atual D+{day}, procedimento: {procedure}.",
        "not_informed": "Não informado",
        "not_defined": "Não definido",
        "referrals": "Indicações feitas",
        "converted": "Indicações convertidas",
        "paid_commissions": "Comissões pagas",
        "total_paid": "Total pago",
        "next_appointments": "Próximos agendamentos",
        "no_upcoming": "Nenhum agendamento futuro encontrado.",
        "appointment_type": "Tipo",
        "appointment_status": "Status",
        "professional": "Profissional",
        "location": "Local",
        "err_credits": "No momento o atendimento da clínica está indisponível. Avise a clínica para regularizar o serviço.",
        "err_key": "No momento o atendimento da clínica ainda não foi configurado corretamente.",
        "err_default": "No momento o atendimento da clínica está indisponível. Tente novamente em instantes.",
    },
    "tr": {
        "base_prompt": "Klinigin sanal asistani sizsiniz. Empati ve netlikle yanit verin.",
        "security_rules": (
            "GUVENLIK KURALLARI (ZORUNLU): sadece kimligi dogrulanmis hasta hakkinda yanit verin. "
            "Diger hastalarin verilerini asla paylasmayin. Bilgi eksikse, bu bilginin sizde olmadigini soyleyin "
            "ve klinikle iletisime yonlendirin."
        ),
        "style_rules": (
            "USLUP KURALLARI (ZORUNLU): emoji, emoticon veya susleyici semboller kullanmayin. "
            "Sade ve acik metin kullanin."
        ),
        "context_title": "DOGRULANMIS HASTA BAGLAMI:",
        "name": "Ad",
        "email": "E-posta",
        "phone": "Telefon",
        "dob": "Dogum tarihi",
        "main_specialty": "Ana uzmanlik",
        "post_op_none": "Aktif bir ameliyat sonrasi surec yok.",
        "post_op_active": "Aktif post-op sureci: ameliyat tarihi {date}, gun D+{day}, islem: {procedure}.",
        "not_informed": "Belirtilmedi",
        "not_defined": "Tanimli degil",
        "referrals": "Yapilan davetler",
        "converted": "Donusen davetler",
        "paid_commissions": "Odenen komisyonlar",
        "total_paid": "Toplam odeme",
        "next_appointments": "Yaklasan randevular",
        "no_upcoming": "Yaklasan randevu bulunamadi.",
        "appointment_type": "Tur",
        "appointment_status": "Durum",
        "professional": "Uzman",
        "location": "Konum",
        "err_credits": "Klinik destegi su anda gecici olarak kullanilamiyor. Lutfen klinikle iletisime gecin.",
        "err_key": "Klinik destegi su anda dogru sekilde yapilandirilmamis.",
        "err_default": "Klinik destegi su anda kullanilamiyor. Lutfen kisa bir sure sonra tekrar deneyin.",
    },
    "de": {
        "base_prompt": "Sie sind die virtuelle Assistentin der Klinik. Antworten Sie empathisch und klar.",
        "security_rules": (
            "SICHERHEITSREGELN (PFLICHT): Antworten Sie nur zum authentifizierten Patienten. "
            "Geben Sie niemals Daten anderer Patienten preis. Wenn Informationen fehlen, sagen Sie das klar "
            "und verweisen Sie auf die Klinik."
        ),
        "style_rules": (
            "STILREGELN (PFLICHT): Verwenden Sie keine Emojis, Emoticons oder dekorativen Symbole. "
            "Nutzen Sie klaren, einfachen Text."
        ),
        "context_title": "KONTEXT DES AUTHENTIFIZIERTEN PATIENTEN:",
        "name": "Name",
        "email": "E-Mail",
        "phone": "Telefon",
        "dob": "Geburtsdatum",
        "main_specialty": "Hauptfachgebiet",
        "post_op_none": "Keine aktive Nachsorge vorhanden.",
        "post_op_active": "Aktive Nachsorge: OP am {date}, aktueller Tag D+{day}, Eingriff: {procedure}.",
        "not_informed": "Nicht angegeben",
        "not_defined": "Nicht definiert",
        "referrals": "Empfehlungen",
        "converted": "Konvertierte Empfehlungen",
        "paid_commissions": "Bezahlte Provisionen",
        "total_paid": "Gesamt bezahlt",
        "next_appointments": "Kommende Termine",
        "no_upcoming": "Keine kommenden Termine gefunden.",
        "appointment_type": "Typ",
        "appointment_status": "Status",
        "professional": "Fachkraft",
        "location": "Ort",
        "err_credits": "Der Klinikservice ist voruebergehend nicht verfuegbar. Bitte kontaktieren Sie die Klinik.",
        "err_key": "Der Klinikservice ist derzeit nicht korrekt konfiguriert.",
        "err_default": "Der Klinikservice ist voruebergehend nicht verfuegbar. Bitte spaeter erneut versuchen.",
    },
    "es": {
        "base_prompt": "Eres la asistente virtual de la clinica. Responde con empatia y claridad.",
        "security_rules": (
            "REGLAS DE SEGURIDAD (OBLIGATORIO): responde solo sobre el paciente autenticado. "
            "Nunca reveles datos de otros pacientes. Si falta informacion, indicalo y orienta contacto con la clinica."
        ),
        "style_rules": (
            "REGLAS DE ESTILO (OBLIGATORIO): no uses emojis, emoticonos ni simbolos decorativos. "
            "Usa texto simple y claro."
        ),
        "context_title": "CONTEXTO DEL PACIENTE AUTENTICADO:",
        "name": "Nombre",
        "email": "Correo",
        "phone": "Telefono",
        "dob": "Fecha de nacimiento",
        "main_specialty": "Especialidad principal",
        "post_op_none": "Sin seguimiento postoperatorio activo.",
        "post_op_active": "Seguimiento postoperatorio activo: cirugia en {date}, dia actual D+{day}, procedimiento: {procedure}.",
        "not_informed": "No informado",
        "not_defined": "No definido",
        "referrals": "Referidos realizados",
        "converted": "Referidos convertidos",
        "paid_commissions": "Comisiones pagadas",
        "total_paid": "Total pagado",
        "next_appointments": "Proximas citas",
        "no_upcoming": "No se encontraron citas futuras.",
        "appointment_type": "Tipo",
        "appointment_status": "Estado",
        "professional": "Profesional",
        "location": "Ubicacion",
        "err_credits": "El servicio de la clinica esta temporalmente no disponible. Contacte la clinica.",
        "err_key": "El servicio de la clinica no esta configurado correctamente en este momento.",
        "err_default": "El servicio de la clinica esta temporalmente no disponible. Intente nuevamente en breve.",
    },
    "ru": {
        "base_prompt": "Vy virtualnyi assistent kliniki. Otvechaite ponyatno i s empatiei.",
        "security_rules": (
            "PRAVILA BEZOPASNOSTI (OBYaZATELNO): otvechaite tolko po avtorizovannomu pacientu. "
            "Nikogda ne raskryvaite dannye drugih pacientov. Esli net dannyh, skazhite ob etom i "
            "napravte k klinike."
        ),
        "style_rules": (
            "PRAVILA STILYa (OBYaZATELNO): ne ispolzuite emodzi, smaily i dekorativnye simvoly. "
            "Ispolzuite prostoi i yasnyi tekst."
        ),
        "context_title": "KONTEKST AVTORIZOVANNOGO PACIENTA:",
        "name": "Imya",
        "email": "Email",
        "phone": "Telefon",
        "dob": "Data rozhdeniya",
        "main_specialty": "Osnovnaya specialnost",
        "post_op_none": "Net aktivnogo posleoperacionnogo marshruta.",
        "post_op_active": "Aktivnyi post-op marshrut: operaciya {date}, tekushchii den D+{day}, procedura: {procedure}.",
        "not_informed": "Ne ukazano",
        "not_defined": "Ne opredeleno",
        "referrals": "Sdelano priglashenii",
        "converted": "Konvertirovano priglashenii",
        "paid_commissions": "Vyplacheno komissii",
        "total_paid": "Vsego vyplacheno",
        "next_appointments": "Blizhaishie priemy",
        "no_upcoming": "Blizhaishie priemy ne naideny.",
        "appointment_type": "Tip",
        "appointment_status": "Status",
        "professional": "Specialist",
        "location": "Mesto",
        "err_credits": "Servis kliniki vremenno nedostupen. Pozhaluista, svyazhites s klinikoi.",
        "err_key": "Servis kliniki seichas nastroen nekorrektno.",
        "err_default": "Servis kliniki vremenno nedostupen. Poprobuite cherez neskolko minut.",
    },
}

APPOINTMENT_TRUTH_RULES = {
    "pt": (
        "REGRAS DE AGENDAMENTO (OBRIGATÓRIO): use apenas a seção 'Próximos agendamentos' do contexto "
        "como fonte da verdade. Nunca invente data/horário/status. Se não houver itens, diga claramente "
        "que não existe agendamento futuro."
    ),
    "en": (
        "APPOINTMENT RULES (MANDATORY): use only the 'Upcoming appointments' section from context as "
        "the source of truth. Never invent date/time/status. If there are no items, clearly state there "
        "are no upcoming appointments."
    ),
    "tr": (
        "RANDEVU KURALLARI (ZORUNLU): yalnizca baglamdaki 'Yaklasan randevular' bolumunu kaynak kabul edin. "
        "Tarih/saat/durum uydurmayin. Liste bos ise, yaklasan randevu olmadigini acikca soyleyin."
    ),
    "de": (
        "TERMINREGELN (PFLICHT): verwenden Sie nur den Abschnitt 'Kommende Termine' im Kontext als "
        "Wahrheitsquelle. Erfinden Sie niemals Datum/Uhrzeit/Status. Wenn keine Eintrage vorhanden sind, "
        "sagen Sie klar, dass es keine kommenden Termine gibt."
    ),
    "es": (
        "REGLAS DE CITAS (OBLIGATORIO): usa solo la sección 'Próximas citas' del contexto como fuente de "
        "verdad. Nunca inventes fecha/hora/estado. Si no hay elementos, indica claramente que no hay citas "
        "próximas."
    ),
    "ru": (
        "PRAVILA PRIEMOV (OBYAZATELNO): ispolzuyte tolko razdel 'Blizhaishie priemy' iz konteksta kak "
        "istochnik istiny. Nikogda ne pridumyvaite datu/vremya/status. Esli spisok pust, yavno skazhite, "
        "chto blizhaishikh priemov net."
    ),
}

AI_ACTIVE_APPOINTMENT_STATUSES = (
    Appointment.StatusChoices.PENDING,
    Appointment.StatusChoices.CONFIRMED,
    Appointment.StatusChoices.IN_PROGRESS,
)


class MessagePagination(PageNumberPagination):
    page_size = 50


def _decode_base64_image(value: str) -> tuple[str, bytes]:
    extension = "png"
    raw_value = value
    if value.startswith("data:image"):
        header, encoded = value.split(",", 1)
        raw_value = encoded
        mime = header.split(";")[0].split(":")[-1]
        if "/" in mime:
            extension = mime.split("/")[-1]

    try:
        decoded = base64.b64decode(raw_value)
    except (binascii.Error, ValueError) as exc:
        raise serializers.ValidationError("Invalid base64 image content.") from exc

    return extension, decoded


def _store_chat_image(content: str, *, room: ChatRoom, request=None) -> str:
    extension, decoded = _decode_base64_image(content)
    normalized_extension = re.sub(r"[^a-z0-9]", "", extension.lower())[:8] or "bin"
    upload_content = ContentFile(decoded, name=f"upload.{normalized_extension}")
    upload_content.content_type = f"image/{normalized_extension}"
    storage_path = build_storage_path(
        room.tenant_id,
        "patients",
        room.patient_id,
        "chat",
        room.id,
        "images",
        upload=upload_content,
    )
    return upload_file(upload_content, storage_path)


def _resolve_language_copy(language: str | None) -> dict[str, str]:
    normalized = normalize_invite_email_language(language)
    return LANGUAGE_COPY.get(normalized, LANGUAGE_COPY["en"])


def _detect_interaction_language(*, text: str, accept_language: str | None) -> str:
    content = (text or "").strip().lower()
    if not content:
        normalized = normalize_invite_email_language(accept_language)
        return normalized if normalized in LANGUAGE_COPY else "en"

    if re.search(r"[\u0400-\u04FF]", content):
        return "ru"
    if re.search(r"[çğıöşü]", content):
        return "tr"
    if re.search(r"[äöüß]", content):
        return "de"
    if any(ch in content for ch in ("¿", "¡", "ñ")):
        return "es"

    keyword_rules = {
        "tr": ("merhaba", "nasilsin", "randevu", "klinik", "ameliyat", "tesekkur"),
        "de": ("hallo", "termin", "klinik", "danke", "schmerzen", "arzt"),
        "es": ("hola", "cita", "clinica", "gracias", "dolor", "doctor"),
        "pt": ("olá", "ola", "agendamento", "consulta", "clínica", "clinica", "obrigado"),
        "en": ("hello", "appointment", "clinic", "thanks", "doctor", "schedule"),
    }
    for lang, words in keyword_rules.items():
        if any(word in content for word in words):
            return lang

    normalized = normalize_invite_email_language(accept_language)
    return normalized if normalized in LANGUAGE_COPY else "en"


def _build_patient_context(patient: Patient, language: str) -> str:
    copy = _resolve_language_copy(language)
    appointments = (
        Appointment.objects.filter(
            patient_id=patient.id,
            tenant_id=patient.tenant_id,
            status__in=AI_ACTIVE_APPOINTMENT_STATUSES,
            appointment_date__gte=timezone.localdate(),
        )
        .select_related("professional", "specialty")
        .order_by("appointment_date", "appointment_time")[:6]
    )
    appointment_lines: list[str] = []
    for item in appointments:
        appointment_lines.append(
            (
                f"- {item.appointment_date} {item.appointment_time} | "
                f"{copy['appointment_type']}: {item.get_appointment_type_display()} | "
                f"{copy['appointment_status']}: {item.get_status_display()} | "
                f"{copy['professional']}: {item.professional.full_name if item.professional else copy['not_defined']} | "
                f"{copy['location']}: {item.clinic_location or copy['not_informed']}"
            )
        )

    journey = (
        PostOpJourney.objects.filter(
            patient_id=patient.id,
            status=PostOpJourney.StatusChoices.ACTIVE,
        )
        .select_related("specialty")
        .order_by("-surgery_date")
        .first()
    )

    referral_qs = Referral.objects.filter(referrer_id=patient.id)
    referral_paid_total = (
        referral_qs.filter(status=Referral.StatusChoices.PAID)
        .aggregate(total=models.Sum("commission_value"))
        .get("total")
        or Decimal("0.00")
    )

    post_op_context = copy["post_op_none"]
    if journey:
        post_op_context = copy["post_op_active"].format(
            date=journey.surgery_date,
            day=journey.current_day,
            procedure=journey.specialty.specialty_name if journey.specialty else copy["not_informed"],
        )

    return (
        f"{copy['context_title']}\n"
        f"- {copy['name']}: {patient.full_name}\n"
        f"- {copy['email']}: {patient.email}\n"
        f"- {copy['phone']}: {patient.phone or copy['not_informed']}\n"
        f"- {copy['dob']}: {patient.date_of_birth or copy['not_informed']}\n"
        f"- {copy['main_specialty']}: {patient.specialty.specialty_name if patient.specialty else copy['not_informed']}\n"
        f"- {post_op_context}\n"
        f"- {copy['referrals']}: {referral_qs.count()} | "
        f"{copy['converted']}: {referral_qs.filter(status=Referral.StatusChoices.CONVERTED).count()} | "
        f"{copy['paid_commissions']}: {referral_qs.filter(status=Referral.StatusChoices.PAID).count()} | "
        f"{copy['total_paid']}: {referral_paid_total}\n"
        f"- {copy['next_appointments']}:\n"
        + ("\n".join(appointment_lines) if appointment_lines else f"- {copy['no_upcoming']}")
    )


def _build_system_prompt(patient: Patient, language: str) -> str:
    copy = _resolve_language_copy(language)
    tenant_prompt = (patient.tenant.ai_assistant_prompt or "").strip() if patient.tenant else ""
    base_prompt = tenant_prompt or copy["base_prompt"]
    privacy_rules = copy["security_rules"]
    style_rules = copy["style_rules"]
    appointment_truth_rules = APPOINTMENT_TRUTH_RULES.get(language, APPOINTMENT_TRUTH_RULES["en"])
    return (
        f"{base_prompt}\n\n"
        f"{privacy_rules}\n\n"
        f"{style_rules}\n\n"
        f"{appointment_truth_rules}\n\n"
        f"{_build_patient_context(patient, language)}"
    )


def _sanitize_ai_content(raw: str) -> str:
    cleaned = (raw or "").replace("\uFFFD", "")
    cleaned = EMOJI_PATTERN.sub("", cleaned)
    cleaned = re.sub(r"[ \t]+\n", "\n", cleaned)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    return cleaned.strip()


def _friendly_ai_error_message(detail: str, language: str) -> str:
    copy = _resolve_language_copy(language)
    lowered = detail.lower()
    if "credits" in lowered or "license" in lowered or "licen" in lowered:
        return copy["err_credits"]
    if "api key" in lowered or "not configured" in lowered:
        return copy["err_key"]
    return copy["err_default"]


def _ai_message_preview(raw_content: str) -> str:
    raw = " ".join((raw_content or "").strip().split())
    if not raw:
        return "Nova mensagem."
    if len(raw) > 140:
        return f"{raw[:137]}..."
    return raw


def _notify_staff_for_human_followup(*, patient: Patient, content: str) -> None:
    from apps.notifications.services import NotificationService

    recipients = GoKlinikUser.objects.filter(
        tenant_id=patient.tenant_id,
        role__in=CHAT_ADMIN_ROLES,
        is_active=True,
    )
    preview = _ai_message_preview(content)
    for recipient in recipients:
        title = "Paciente aguardando equipe humana"
        body = f"{patient.full_name}: {preview}"
        payload = {
            "event": "chat_ai_human_followup",
            "patient_id": str(patient.id),
        }
        try:
            NotificationService.send_push_to_user(
                user=recipient,
                title=title,
                body=body,
                data_extra=payload,
                event_code="chat_ai_human_followup",
                segment="chat",
                idempotency_key=f"chat_ai_human_followup:{patient.id}:{recipient.id}:{timezone.now().isoformat()}",
                notification_type="new_message",
                related_object_id=patient.id,
                create_in_app_notification=False,
            )
        except Exception:  # noqa: BLE001
            logger.exception(
                "Unable to notify staff for human followup patient=%s recipient=%s",
                patient.id,
                recipient.id,
            )

        try:
            NotificationService.create_in_app_notification(
                recipient=recipient,
                title=title,
                body=body,
                notification_type="new_message",
                related_object_id=patient.id,
            )
        except Exception:  # noqa: BLE001
            logger.exception(
                "Unable to create staff in-app notification patient=%s recipient=%s",
                patient.id,
                recipient.id,
            )


def _notify_patient_about_staff_ai_message(
    *,
    patient: Patient,
    staff_user: GoKlinikUser,
    content: str,
) -> None:
    from apps.notifications.services import NotificationService

    title = "Nova mensagem da clínica"
    preview = _ai_message_preview(content)
    body = f"{staff_user.full_name}: {preview}"
    payload = {
        "event": "chat_ai_staff_message",
        "patient_id": str(patient.id),
        "sender_id": str(staff_user.id),
    }
    try:
        NotificationService.send_push_to_user(
            user=patient,
            title=title,
            body=body,
            data_extra=payload,
            event_code="chat_ai_staff_message",
            segment="chat",
            idempotency_key=f"chat_ai_staff_message:{patient.id}:{staff_user.id}:{timezone.now().isoformat()}",
            notification_type="new_message",
            related_object_id=patient.id,
            create_in_app_notification=False,
        )
    except Exception:  # noqa: BLE001
        logger.exception(
            "Unable to send patient push for staff ai message patient=%s sender=%s",
            patient.id,
            staff_user.id,
        )

    try:
        NotificationService.create_in_app_notification(
            recipient=patient,
            title=title,
            body=body,
            notification_type="new_message",
            related_object_id=patient.id,
        )
    except Exception:  # noqa: BLE001
        logger.exception(
            "Unable to persist patient in-app for staff ai message patient=%s sender=%s",
            patient.id,
            staff_user.id,
        )


def _chat_message_preview(message: Message) -> str:
    if message.message_type == Message.MessageTypeChoices.IMAGE:
        return "Enviou uma imagem."
    raw = " ".join((message.content or "").strip().split())
    if not raw:
        return "Nova mensagem."
    if len(raw) > 140:
        return f"{raw[:137]}..."
    return raw


def _resolve_chat_message_recipients(message: Message) -> list[GoKlinikUser]:
    sender = message.sender
    room = message.room
    recipients: dict[str, GoKlinikUser] = {}

    if sender.role == GoKlinikUser.RoleChoices.PATIENT:
        staff_member = room.staff_member
        if staff_member and staff_member.is_active and staff_member.id != sender.id:
            recipients[str(staff_member.id)] = staff_member

        clinic_masters = GoKlinikUser.objects.filter(
            tenant_id=room.tenant_id,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
            is_active=True,
        ).exclude(id=sender.id)
        for clinic_master in clinic_masters:
            recipients[str(clinic_master.id)] = clinic_master
    elif sender.role in STAFF_ROLES:
        patient = room.patient
        if patient and patient.is_active and patient.id != sender.id:
            recipients[str(patient.id)] = patient

    return list(recipients.values())


def _notify_chat_message(message: Message) -> None:
    from apps.notifications.services import NotificationService

    recipients = _resolve_chat_message_recipients(message)
    if not recipients:
        return

    sender_name = message.sender.full_name
    preview = _chat_message_preview(message)
    room_id = str(message.room_id)
    message_id = str(message.id)

    for recipient in recipients:
        if recipient.role == GoKlinikUser.RoleChoices.PATIENT:
            title = "Nova mensagem da clínica"
        else:
            title = f"Nova mensagem de {sender_name}"

        body = f"{sender_name}: {preview}"
        payload = {
            "event": "chat_new_message",
            "room_id": room_id,
            "message_id": message_id,
            "sender_id": str(message.sender_id),
            "sender_role": message.sender.role,
        }

        try:
            NotificationService.send_push_to_user(
                user=recipient,
                title=title,
                body=body,
                data_extra=payload,
                event_code="chat_new_message",
                segment="chat",
                idempotency_key=f"chat_message:{message_id}:{recipient.id}",
                notification_type="new_message",
                related_object_id=message.room_id,
                create_in_app_notification=False,
            )
        except Exception:  # noqa: BLE001
            logger.exception(
                "Unable to send chat push notification message=%s recipient=%s",
                message_id,
                recipient.id,
            )

        try:
            NotificationService.create_in_app_notification(
                recipient=recipient,
                title=title,
                body=body,
                notification_type="new_message",
                related_object_id=message.room_id,
            )
        except Exception:  # noqa: BLE001
            logger.exception(
                "Unable to persist chat in-app notification message=%s recipient=%s",
                message_id,
                recipient.id,
            )


class ChatRoomViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    pagination_class = None

    def _assert_allowed_role(self):
        user = self.request.user
        if user.role == GoKlinikUser.RoleChoices.SUPER_ADMIN:
            raise PermissionDenied("SaaS owner cannot access clinic chat rooms.")

    def get_queryset(self):
        self._assert_allowed_role()
        user = self.request.user
        queryset = ChatRoom.objects.select_related("patient", "staff_member", "tenant")

        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            return queryset.filter(patient_id=user.id)

        if user.role in STAFF_ROLES:
            return queryset.filter(tenant_id=user.tenant_id)

        return queryset.none()

    def list(self, request):
        queryset = self.get_queryset()
        serializer = ChatRoomListSerializer(queryset, many=True, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    def create(self, request):
        self._assert_allowed_role()
        payload_serializer = ChatRoomCreateSerializer(data=request.data)
        payload_serializer.is_valid(raise_exception=True)
        payload = payload_serializer.validated_data

        user = request.user
        patient = Patient.objects.filter(id=payload["patient_id"]).first()
        if not patient:
            return Response({"detail": "Patient not found."}, status=status.HTTP_404_NOT_FOUND)

        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            if str(user.id) != str(patient.id):
                return Response(status=status.HTTP_403_FORBIDDEN)
            tenant = patient.tenant
            staff_member = (
                GoKlinikUser.objects.filter(tenant=tenant, role__in=STAFF_ROLES, is_active=True)
                .order_by("role", "date_joined")
                .first()
            )
            if not staff_member:
                return Response(
                    {"detail": "No staff member available for this tenant."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        elif user.role in STAFF_ROLES:
            if patient.tenant_id != user.tenant_id:
                return Response(status=status.HTTP_403_FORBIDDEN)
            tenant = user.tenant
            staff_member = user
        else:
            return Response(status=status.HTTP_403_FORBIDDEN)

        existing = (
            ChatRoom.objects.select_related("patient", "staff_member")
            .filter(
                tenant=tenant,
                patient=patient,
                room_type=payload["room_type"],
            )
            .first()
        )
        if existing:
            data = ChatRoomListSerializer(existing, context={"request": request}).data
            return Response(data, status=status.HTTP_200_OK)

        room = ChatRoom.objects.create(
            tenant=tenant,
            patient=patient,
            staff_member=staff_member,
            room_type=payload["room_type"],
        )
        data = ChatRoomListSerializer(room, context={"request": request}).data
        return Response(data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=["get", "post"], url_path="messages")
    def messages(self, request, pk=None):
        room = self.get_object()

        if request.method == "GET":
            paginator = MessagePagination()
            queryset = room.messages.select_related("sender").order_by("-created_at")
            page = paginator.paginate_queryset(queryset, request)
            serializer = MessageSerializer(page, many=True, context={"request": request})
            return paginator.get_paginated_response(serializer.data)

        payload_serializer = ChatMessageCreateSerializer(data=request.data)
        payload_serializer.is_valid(raise_exception=True)
        payload = payload_serializer.validated_data

        content = payload["content"]
        if payload["message_type"] == Message.MessageTypeChoices.IMAGE:
            if content.startswith("http://") or content.startswith("https://"):
                normalized_content = absolute_media_url(content, request=request)
            else:
                try:
                    normalized_content = _store_chat_image(
                        content,
                        room=room,
                        request=request,
                    )
                except SupabaseStorageError as exc:
                    return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
        else:
            normalized_content = content

        message = Message.objects.create(
            room=room,
            sender=request.user,
            content=normalized_content,
            message_type=payload["message_type"],
        )
        room.last_message_at = message.created_at
        room.save(update_fields=["last_message_at"])
        _notify_chat_message(message)

        return Response(
            MessageSerializer(message, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["put"], url_path="read")
    def mark_read(self, request, pk=None):
        room = self.get_object()
        user = request.user
        now = timezone.now()

        unread = room.messages.exclude(sender_id=user.id).filter(is_read=False)
        marked_count = unread.count()
        unread.update(is_read=True, read_at=now)

        return Response({"marked_count": marked_count}, status=status.HTTP_200_OK)

    def get_object(self):
        return get_object_or_404(self.get_queryset(), id=self.kwargs["pk"])


class PatientAIChatAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def _get_patient(self, request) -> Patient | None:
        if request.user.role != GoKlinikUser.RoleChoices.PATIENT:
            return None
        return Patient.objects.select_related("tenant", "specialty").filter(id=request.user.id).first()

    def get(self, request):
        patient = self._get_patient(request)
        if not patient:
            return Response(status=status.HTTP_403_FORBIDDEN)

        messages = PatientAIMessage.objects.filter(patient_id=patient.id).order_by("created_at")
        return Response(PatientAIMessageSerializer(messages, many=True).data, status=status.HTTP_200_OK)

    def post(self, request):
        patient = self._get_patient(request)
        if not patient:
            return Response(status=status.HTTP_403_FORBIDDEN)

        input_serializer = PatientAIMessageCreateSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)
        user_content = input_serializer.validated_data["content"].strip()

        user_message = PatientAIMessage.objects.create(
            tenant_id=patient.tenant_id,
            patient_id=patient.id,
            role=PatientAIMessage.RoleChoices.USER,
            source=PatientAIMessage.SourceChoices.PATIENT,
            sender_user_id=request.user.id,
            content=user_content,
        )

        ai_enabled = _is_patient_ai_enabled(
            tenant_id=patient.tenant_id,
            patient_id=patient.id,
        )
        if not ai_enabled:
            _notify_staff_for_human_followup(patient=patient, content=user_content)
            serialized_history = PatientAIMessageSerializer(
                PatientAIMessage.objects.filter(patient_id=patient.id).order_by("created_at"),
                many=True,
            ).data
            return Response(
                {
                    "user_message": PatientAIMessageSerializer(user_message).data,
                    "assistant_message": None,
                    "messages": serialized_history,
                    "mode": "human",
                },
                status=status.HTTP_201_CREATED,
            )

        recent_messages = list(
            PatientAIMessage.objects.filter(patient_id=patient.id).order_by("-created_at")[:20]
        )
        recent_messages.reverse()

        interaction_language = _detect_interaction_language(
            text=user_content,
            accept_language=request.headers.get("Accept-Language"),
        )

        llm_messages: list[dict] = [
            {"role": "system", "content": _build_system_prompt(patient, interaction_language)}
        ]
        llm_messages.extend({"role": item.role, "content": item.content} for item in recent_messages)

        provider_error = ""
        try:
            ai_config = resolve_ai_runtime_config()
            ai_answer = request_chat_completion(messages=llm_messages, config=ai_config)
            assistant_message = PatientAIMessage.objects.create(
                tenant_id=patient.tenant_id,
                patient_id=patient.id,
                role=PatientAIMessage.RoleChoices.ASSISTANT,
                source=PatientAIMessage.SourceChoices.AI,
                content=_sanitize_ai_content(ai_answer),
            )
        except AIServiceError as exc:
            provider_error = str(exc)
            assistant_message = PatientAIMessage.objects.create(
                tenant_id=patient.tenant_id,
                patient_id=patient.id,
                role=PatientAIMessage.RoleChoices.ASSISTANT,
                source=PatientAIMessage.SourceChoices.SYSTEM,
                content=_friendly_ai_error_message(provider_error, interaction_language),
            )

        serialized_history = PatientAIMessageSerializer(
            PatientAIMessage.objects.filter(patient_id=patient.id).order_by("created_at"),
            many=True,
        ).data
        payload = {
            "user_message": PatientAIMessageSerializer(user_message).data,
            "assistant_message": PatientAIMessageSerializer(assistant_message).data,
            "messages": serialized_history,
        }
        if provider_error:
            payload["provider_error"] = provider_error

        return Response(payload, status=status.HTTP_201_CREATED)


class ChatAIAdminMixin:
    def _get_admin_user(self, request) -> GoKlinikUser | None:
        user = request.user
        if not _is_chat_admin(user):
            return None
        if not user.tenant_id:
            return None
        return user

    def _get_tenant_patient(self, *, tenant_id, patient_id) -> Patient | None:
        return (
            Patient.objects.select_related("tenant")
            .filter(id=patient_id, tenant_id=tenant_id)
            .first()
        )


class ChatAIAdminSettingsAPIView(ChatAIAdminMixin, APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = self._get_admin_user(request)
        if not user:
            return Response(status=status.HTTP_403_FORBIDDEN)
        settings_obj = _get_or_create_tenant_ai_settings(user.tenant_id)
        return Response(TenantAIChatSettingsSerializer(settings_obj).data, status=status.HTTP_200_OK)

    def put(self, request):
        user = self._get_admin_user(request)
        if not user:
            return Response(status=status.HTTP_403_FORBIDDEN)

        settings_obj = _get_or_create_tenant_ai_settings(user.tenant_id)
        serializer = TenantAIChatSettingsSerializer(
            settings_obj,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save(updated_by=user)
        return Response(serializer.data, status=status.HTTP_200_OK)


class ChatAIAdminConversationListAPIView(ChatAIAdminMixin, APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = self._get_admin_user(request)
        if not user:
            return Response(status=status.HTTP_403_FORBIDDEN)

        search = (request.query_params.get("search") or "").strip()
        messages_qs = PatientAIMessage.objects.filter(patient_id=OuterRef("id")).order_by("-created_at")
        control_qs = PatientAIConversationControl.objects.filter(patient_id=OuterRef("id"))
        patients_qs = (
            Patient.objects.filter(tenant_id=user.tenant_id, ai_messages__isnull=False)
            .distinct()
            .annotate(
                last_message_at=Subquery(messages_qs.values("created_at")[:1]),
                last_message_content=Subquery(messages_qs.values("content")[:1]),
                last_message_role=Subquery(messages_qs.values("role")[:1]),
                last_message_source=Subquery(messages_qs.values("source")[:1]),
                force_human=Subquery(control_qs.values("force_human")[:1]),
            )
            .order_by("-last_message_at", "first_name", "last_name", "email")
        )

        if search:
            patients_qs = patients_qs.filter(
                models.Q(first_name__icontains=search)
                | models.Q(last_name__icontains=search)
                | models.Q(email__icontains=search)
            )

        tenant_settings = _get_or_create_tenant_ai_settings(user.tenant_id)
        payload = []
        for patient in patients_qs:
            force_human = bool(patient.force_human)
            payload.append(
                {
                    "patient_id": str(patient.id),
                    "patient_name": patient.full_name,
                    "patient_email": patient.email,
                    "patient_avatar_url": patient.avatar_url or "",
                    "last_message_at": patient.last_message_at,
                    "last_message_preview": _ai_message_preview(patient.last_message_content or ""),
                    "last_message_role": patient.last_message_role or "",
                    "last_message_source": patient.last_message_source or "",
                    "force_human": force_human,
                    "effective_ai_enabled": bool(tenant_settings.ai_enabled and not force_human),
                }
            )

        return Response(
            {
                "global_ai_enabled": tenant_settings.ai_enabled,
                "results": payload,
            },
            status=status.HTTP_200_OK,
        )


class ChatAIAdminConversationMessagesAPIView(ChatAIAdminMixin, APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, patient_id):
        user = self._get_admin_user(request)
        if not user:
            return Response(status=status.HTTP_403_FORBIDDEN)

        patient = self._get_tenant_patient(tenant_id=user.tenant_id, patient_id=patient_id)
        if not patient:
            return Response({"detail": "Patient not found."}, status=status.HTTP_404_NOT_FOUND)

        tenant_settings = _get_or_create_tenant_ai_settings(user.tenant_id)
        control = _get_or_create_patient_ai_control(tenant_id=user.tenant_id, patient_id=patient.id)
        messages = PatientAIMessage.objects.filter(patient_id=patient.id).order_by("created_at")
        return Response(
            {
                "patient": {
                    "id": str(patient.id),
                    "name": patient.full_name,
                    "email": patient.email,
                    "avatar_url": patient.avatar_url or "",
                },
                "global_ai_enabled": tenant_settings.ai_enabled,
                "force_human": control.force_human,
                "effective_ai_enabled": bool(tenant_settings.ai_enabled and not control.force_human),
                "messages": PatientAIMessageSerializer(messages, many=True).data,
            },
            status=status.HTTP_200_OK,
        )

    def post(self, request, patient_id):
        user = self._get_admin_user(request)
        if not user:
            return Response(status=status.HTTP_403_FORBIDDEN)

        patient = self._get_tenant_patient(tenant_id=user.tenant_id, patient_id=patient_id)
        if not patient:
            return Response({"detail": "Patient not found."}, status=status.HTTP_404_NOT_FOUND)

        input_serializer = StaffPatientAIMessageCreateSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)
        content = input_serializer.validated_data["content"].strip()

        message = PatientAIMessage.objects.create(
            tenant_id=user.tenant_id,
            patient_id=patient.id,
            role=PatientAIMessage.RoleChoices.ASSISTANT,
            source=PatientAIMessage.SourceChoices.STAFF,
            sender_user_id=user.id,
            content=content,
        )

        typing_status, _ = PatientAITypingStatus.objects.get_or_create(
            tenant_id=user.tenant_id,
            patient_id=patient.id,
        )
        typing_status.is_typing = False
        typing_status.typed_by = user
        typing_status.expires_at = timezone.now()
        typing_status.save(update_fields=["is_typing", "typed_by", "expires_at", "updated_at"])

        _notify_patient_about_staff_ai_message(patient=patient, staff_user=user, content=content)
        return Response(PatientAIMessageSerializer(message).data, status=status.HTTP_201_CREATED)


class ChatAIAdminPatientModeAPIView(ChatAIAdminMixin, APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request, patient_id):
        user = self._get_admin_user(request)
        if not user:
            return Response(status=status.HTTP_403_FORBIDDEN)

        patient = self._get_tenant_patient(tenant_id=user.tenant_id, patient_id=patient_id)
        if not patient:
            return Response({"detail": "Patient not found."}, status=status.HTTP_404_NOT_FOUND)

        control = _get_or_create_patient_ai_control(tenant_id=user.tenant_id, patient_id=patient.id)
        serializer = PatientAIConversationControlSerializer(control, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save(updated_by=user)

        tenant_settings = _get_or_create_tenant_ai_settings(user.tenant_id)
        data = serializer.data
        data["effective_ai_enabled"] = bool(tenant_settings.ai_enabled and not control.force_human)
        return Response(data, status=status.HTTP_200_OK)


class ChatAIAdminTypingAPIView(ChatAIAdminMixin, APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request, patient_id):
        user = self._get_admin_user(request)
        if not user:
            return Response(status=status.HTTP_403_FORBIDDEN)

        patient = self._get_tenant_patient(tenant_id=user.tenant_id, patient_id=patient_id)
        if not patient:
            return Response({"detail": "Patient not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = PatientAITypingUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        is_typing = serializer.validated_data["is_typing"]

        status_obj, _ = PatientAITypingStatus.objects.get_or_create(
            tenant_id=user.tenant_id,
            patient_id=patient.id,
        )
        status_obj.is_typing = is_typing
        status_obj.typed_by = user if is_typing else None
        status_obj.expires_at = (
            timezone.now() + timedelta(seconds=AI_TYPING_TTL_SECONDS)
            if is_typing
            else timezone.now()
        )
        status_obj.save(update_fields=["is_typing", "typed_by", "expires_at", "updated_at"])

        return Response(
            {
                "is_typing": status_obj.is_typing,
                "expires_at": status_obj.expires_at,
            },
            status=status.HTTP_200_OK,
        )


class PatientAITypingStatusAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def _get_patient(self, request) -> Patient | None:
        if request.user.role != GoKlinikUser.RoleChoices.PATIENT:
            return None
        return Patient.objects.filter(id=request.user.id).first()

    def get(self, request):
        patient = self._get_patient(request)
        if not patient:
            return Response(status=status.HTTP_403_FORBIDDEN)

        typing_status = (
            PatientAITypingStatus.objects.select_related("typed_by")
            .filter(tenant_id=patient.tenant_id, patient_id=patient.id)
            .first()
        )
        if not typing_status:
            return Response({"is_typing": False}, status=status.HTTP_200_OK)

        now = timezone.now()
        is_typing = bool(
            typing_status.is_typing
            and typing_status.expires_at
            and typing_status.expires_at > now
        )
        if typing_status.is_typing and not is_typing:
            typing_status.is_typing = False
            typing_status.typed_by = None
            typing_status.save(update_fields=["is_typing", "typed_by", "updated_at"])

        return Response(
            {
                "is_typing": is_typing,
                "typed_by": typing_status.typed_by.full_name if is_typing and typing_status.typed_by else "",
                "expires_at": typing_status.expires_at,
            },
            status=status.HTTP_200_OK,
        )
