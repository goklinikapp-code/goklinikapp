from __future__ import annotations

import json
import logging
from html import escape
from urllib import error as urllib_error
from urllib import request as urllib_request

from django.conf import settings
from django.core.mail import send_mail

logger = logging.getLogger(__name__)


class InviteEmailError(Exception):
    pass


INVITE_EMAIL_COPY = {
    "en": {
        "subject": "Invitation to join {clinic_name}",
        "greeting": "Hello {full_name},",
        "invitation_line": "You were invited to join {clinic_name} as {role_name}.",
        "email_label": "Email",
        "temporary_password_label": "Temporary password",
        "login_label": "Login here",
        "open_login_page": "Open login page",
        "after_login": "After your first login, please change your password.",
    },
    "pt": {
        "subject": "Convite para entrar na {clinic_name}",
        "greeting": "Olá {full_name},",
        "invitation_line": "Você foi convidado(a) para entrar na {clinic_name} como {role_name}.",
        "email_label": "E-mail",
        "temporary_password_label": "Senha temporária",
        "login_label": "Acesse aqui",
        "open_login_page": "Abrir página de login",
        "after_login": "Após o primeiro acesso, altere sua senha.",
    },
    "es": {
        "subject": "Invitacion para unirse a {clinic_name}",
        "greeting": "Hola {full_name},",
        "invitation_line": "Has sido invitado(a) a unirte a {clinic_name} como {role_name}.",
        "email_label": "Correo",
        "temporary_password_label": "Contrasena temporal",
        "login_label": "Inicia sesion aqui",
        "open_login_page": "Abrir pagina de inicio de sesion",
        "after_login": "Despues del primer acceso, cambia tu contrasena.",
    },
    "de": {
        "subject": "Einladung zum Beitritt zu {clinic_name}",
        "greeting": "Hallo {full_name},",
        "invitation_line": "Sie wurden eingeladen, {clinic_name} als {role_name} beizutreten.",
        "email_label": "E-Mail",
        "temporary_password_label": "Temporeres Passwort",
        "login_label": "Hier einloggen",
        "open_login_page": "Login-Seite offnen",
        "after_login": "Bitte andern Sie Ihr Passwort nach dem ersten Login.",
    },
    "tr": {
        "subject": "{clinic_name} ekibine davet",
        "greeting": "Merhaba {full_name},",
        "invitation_line": "{clinic_name} ekibine {role_name} olarak davet edildiniz.",
        "email_label": "E-posta",
        "temporary_password_label": "Gecici sifre",
        "login_label": "Giris sayfasi",
        "open_login_page": "Giris sayfasini ac",
        "after_login": "Ilk giristen sonra lutfen sifrenizi degistirin.",
    },
    "ru": {
        "subject": "Priglashenie prisoedinitsya k {clinic_name}",
        "greeting": "Privet {full_name},",
        "invitation_line": "Vas priglasili prisoedinitsya k {clinic_name} v roli {role_name}.",
        "email_label": "Email",
        "temporary_password_label": "Vremennyy parol",
        "login_label": "Vhod zdes",
        "open_login_page": "Otkryt stranicu vhoda",
        "after_login": "Posle pervogo vhoda izmenite parol.",
    },
}

ROLE_LABELS_BY_LANGUAGE = {
    "en": {
        "super_admin": "Super Admin",
        "clinic_master": "Clinic Master",
        "surgeon": "Surgeon",
        "secretary": "Secretary",
        "nurse": "Nurse",
        "patient": "Patient",
    },
    "pt": {
        "super_admin": "Super Admin",
        "clinic_master": "Dono da Clínica",
        "surgeon": "Cirurgião",
        "secretary": "Secretária",
        "nurse": "Enfermagem",
        "patient": "Paciente",
    },
    "es": {
        "super_admin": "Super Admin",
        "clinic_master": "Administrador de clinica",
        "surgeon": "Cirujano",
        "secretary": "Secretaria",
        "nurse": "Enfermeria",
        "patient": "Paciente",
    },
    "de": {
        "super_admin": "Super Admin",
        "clinic_master": "Klinikleiter",
        "surgeon": "Chirurg",
        "secretary": "Sekretariat",
        "nurse": "Pflege",
        "patient": "Patient",
    },
    "tr": {
        "super_admin": "Super Admin",
        "clinic_master": "Klinik Yoneticisi",
        "surgeon": "Cerrah",
        "secretary": "Sekreter",
        "nurse": "Hemsire",
        "patient": "Hasta",
    },
    "ru": {
        "super_admin": "Super Admin",
        "clinic_master": "Rukovoditel kliniki",
        "surgeon": "Hirurg",
        "secretary": "Sekretar",
        "nurse": "Medsestra",
        "patient": "Pacient",
    },
}


def normalize_invite_email_language(raw_language: str | None) -> str:
    if not raw_language:
        return "en"

    normalized = str(raw_language).strip().lower()
    if not normalized:
        return "en"

    normalized = normalized.split(",", 1)[0].strip()
    normalized = normalized.split(";", 1)[0].strip().replace("_", "-")

    if normalized in INVITE_EMAIL_COPY:
        return normalized

    short_code = normalized.split("-", 1)[0]
    if short_code in INVITE_EMAIL_COPY:
        return short_code

    return "en"


def _localized_role_name(*, invited_user, language: str) -> str:
    role_value = getattr(invited_user, "role", "")
    role_map = ROLE_LABELS_BY_LANGUAGE.get(language, ROLE_LABELS_BY_LANGUAGE["en"])
    if role_value in role_map:
        return role_map[role_value]
    return invited_user.get_role_display()


def _friendly_resend_error(raw_body: str) -> str:
    body = (raw_body or "").lower()
    if "testing emails to your own email address" in body or "verify a domain" in body:
        return (
            "Resend is in testing mode for this sender. Verify a domain in Resend and "
            "use a sender email from that domain to send invites to other recipients."
        )
    if "1010" in body:
        return (
            "Resend rejected the send (code 1010). Verify your sender domain/email in "
            "Resend and try again."
        )
    if "forbidden" in body or "403" in body:
        return "Resend rejected the send. Check API key permissions and sender identity."
    return "Could not send invitation email with Resend."


def _build_login_url() -> str:
    base_url = (getattr(settings, "FRONTEND_BASE_URL", "") or "https://goklinik.com").strip()
    login_path = (getattr(settings, "TEAM_INVITE_LOGIN_PATH", "") or "/login").strip()

    if not login_path.startswith("/"):
        login_path = f"/{login_path}"

    return f"{base_url.rstrip('/')}{login_path}"


def _send_with_resend(
    *,
    api_key: str,
    sender: str,
    recipient: str,
    subject: str,
    html: str,
    text: str,
) -> None:
    payload = {
        "from": sender,
        "to": [recipient],
        "subject": subject,
        "html": html,
        "text": text,
    }
    request_payload = json.dumps(payload).encode("utf-8")

    req = urllib_request.Request(
        url="https://api.resend.com/emails",
        data=request_payload,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "User-Agent": "GoKlinik-Backend/1.0",
        },
    )

    try:
        with urllib_request.urlopen(req, timeout=15) as response:
            status_code = response.getcode()
            if status_code >= 300:
                body = response.read().decode("utf-8", errors="ignore")
                logger.warning("Resend returned status=%s body=%s", status_code, body)
                raise InviteEmailError(_friendly_resend_error(body))
    except urllib_error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        logger.warning("Resend HTTP error status=%s body=%s", exc.code, body)
        raise InviteEmailError(_friendly_resend_error(body))
    except urllib_error.URLError as exc:
        logger.warning("Resend connection error: %s", exc)
        raise InviteEmailError("Could not connect to Resend to send invitation email.")


def send_team_invite_email(
    *,
    invited_user,
    inviter,
    temporary_password: str,
    language: str | None = None,
) -> None:
    clinic_name = "GoKlinik"
    if getattr(inviter, "tenant", None) and getattr(inviter.tenant, "name", None):
        clinic_name = inviter.tenant.name

    email_language = normalize_invite_email_language(language)
    copy = INVITE_EMAIL_COPY[email_language]
    login_url = _build_login_url()
    role_name = _localized_role_name(invited_user=invited_user, language=email_language)
    safe_email = escape(invited_user.email)
    safe_temp_password = escape(temporary_password)
    safe_login_url = escape(login_url, quote=True)
    safe_open_login_page = escape(copy["open_login_page"])
    safe_after_login = escape(copy["after_login"])
    safe_greeting = escape(copy["greeting"].format(full_name=invited_user.full_name))
    safe_invitation_line = escape(
        copy["invitation_line"].format(clinic_name=clinic_name, role_name=role_name)
    )
    safe_email_label = escape(copy["email_label"])
    safe_temporary_password_label = escape(copy["temporary_password_label"])

    subject = copy["subject"].format(clinic_name=clinic_name)
    text = (
        f'{copy["greeting"].format(full_name=invited_user.full_name)}\n\n'
        f'{copy["invitation_line"].format(clinic_name=clinic_name, role_name=role_name)}\n\n'
        f'{copy["email_label"]}: {invited_user.email}\n'
        f'{copy["temporary_password_label"]}: {temporary_password}\n\n'
        f'{copy["login_label"]}: {login_url}\n\n'
        f'{copy["after_login"]}'
    )
    html = (
        '<div style="font-family: Arial, sans-serif; color: #1f2937; line-height: 1.5;">'
        f'<p style="margin: 0 0 12px 0;">{safe_greeting}</p>'
        f'<p style="margin: 0 0 12px 0;">{safe_invitation_line}</p>'
        f'<p style="margin: 0 0 12px 0;"><strong>{safe_email_label}:</strong> {safe_email}<br/>'
        f"<strong>{safe_temporary_password_label}:</strong> {safe_temp_password}</p>"
        f'<p style="margin: 0 0 12px 0;"><a href="{safe_login_url}" target="_blank" rel="noreferrer">{safe_open_login_page}</a></p>'
        f'<p style="margin: 0;">{safe_after_login}</p>'
        "</div>"
    )

    resend_api_key = (getattr(settings, "RESEND_API_KEY", "") or "").strip()
    resend_sender = (
        getattr(settings, "RESEND_FROM_EMAIL", None) or settings.DEFAULT_FROM_EMAIL
    )

    if resend_api_key:
        _send_with_resend(
            api_key=resend_api_key,
            sender=resend_sender,
            recipient=invited_user.email,
            subject=subject,
            html=html,
            text=text,
        )
        return

    send_mail(
        subject=subject,
        message=text,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[invited_user.email],
        fail_silently=False,
    )
