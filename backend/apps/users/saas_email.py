from __future__ import annotations

import json
import logging
from html import escape
from urllib import error as urllib_error
from urllib import request as urllib_request

from django.conf import settings
from django.core.mail import send_mail

from .invite_email import InviteEmailError, normalize_invite_email_language

logger = logging.getLogger(__name__)


SIGNUP_CODE_COPY = {
    "en": {
        "subject": "Confirm your GoKlinik clinic registration",
        "title": "Your verification code",
        "line_1": "Use this code to finish your clinic registration:",
        "line_2": "This code expires in 15 minutes.",
        "line_3": "If you did not request this, ignore this email.",
    },
    "pt": {
        "subject": "Confirme o cadastro da sua clínica no GoKlinik",
        "title": "Seu código de verificação",
        "line_1": "Use este código para concluir o cadastro da clínica:",
        "line_2": "Este código expira em 15 minutos.",
        "line_3": "Se você não solicitou, ignore este e-mail.",
    },
}

SAAS_INVITE_COPY = {
    "en": {
        "subject": "Invitation to create your clinic account",
        "greeting": "Hello {name},",
        "line_1": "You were invited to create and manage the clinic {clinic}.",
        "line_2": "Click below to create your password and activate your account:",
        "cta": "Create my password",
        "line_3": "This invitation expires in 7 days.",
    },
    "pt": {
        "subject": "Convite para criar a conta da sua clínica",
        "greeting": "Olá {name},",
        "line_1": "Você foi convidado(a) para criar e gerenciar a clínica {clinic}.",
        "line_2": "Clique abaixo para definir sua senha e ativar a conta:",
        "cta": "Criar minha senha",
        "line_3": "Este convite expira em 7 dias.",
    },
}


def _friendly_resend_error(raw_body: str) -> str:
    body = (raw_body or "").lower()
    if "testing emails to your own email address" in body or "verify a domain" in body:
        return (
            "Resend está em modo de testes para este remetente. Verifique um domínio no "
            "Resend e use um e-mail remetente desse domínio."
        )
    if "forbidden" in body or "403" in body:
        return "Resend rejeitou o envio. Verifique permissões da API e identidade do remetente."
    return "Não foi possível enviar e-mail com Resend."


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
    req = urllib_request.Request(
        url="https://api.resend.com/emails",
        data=json.dumps(payload).encode("utf-8"),
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
                logger.warning("Resend status=%s body=%s", status_code, body)
                raise InviteEmailError(_friendly_resend_error(body))
    except urllib_error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        logger.warning("Resend HTTP status=%s body=%s", exc.code, body)
        raise InviteEmailError(_friendly_resend_error(body))
    except urllib_error.URLError as exc:
        logger.warning("Resend connection error: %s", exc)
        raise InviteEmailError("Não foi possível conectar ao Resend.")


def _send_email(*, recipient: str, subject: str, text: str, html: str) -> None:
    resend_api_key = (getattr(settings, "RESEND_API_KEY", "") or "").strip()
    sender = getattr(settings, "RESEND_FROM_EMAIL", None) or settings.DEFAULT_FROM_EMAIL

    if resend_api_key:
        _send_with_resend(
            api_key=resend_api_key,
            sender=sender,
            recipient=recipient,
            subject=subject,
            html=html,
            text=text,
        )
        return

    send_mail(
        subject=subject,
        message=text,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[recipient],
        fail_silently=False,
    )


def send_signup_code_email(*, email: str, code: str, language: str | None = None) -> None:
    locale = normalize_invite_email_language(language)
    copy = SIGNUP_CODE_COPY.get(locale, SIGNUP_CODE_COPY["en"])

    subject = copy["subject"]
    safe_code = escape(code)
    text = (
        f'{copy["title"]}\n\n'
        f'{copy["line_1"]}\n'
        f"{code}\n\n"
        f'{copy["line_2"]}\n'
        f'{copy["line_3"]}'
    )
    html = (
        '<div style="font-family: Arial, sans-serif; color: #1f2937; line-height: 1.5;">'
        f'<p style="margin: 0 0 10px 0;"><strong>{escape(copy["title"])}</strong></p>'
        f'<p style="margin: 0 0 10px 0;">{escape(copy["line_1"])}</p>'
        f'<p style="margin: 0 0 14px 0; font-size: 28px; letter-spacing: 4px; font-weight: 700;">{safe_code}</p>'
        f'<p style="margin: 0 0 8px 0;">{escape(copy["line_2"])}</p>'
        f'<p style="margin: 0;">{escape(copy["line_3"])}</p>'
        "</div>"
    )
    _send_email(recipient=email, subject=subject, text=text, html=html)


def send_saas_invite_email(
    *,
    email: str,
    full_name: str,
    clinic_name: str,
    invite_token: str,
    language: str | None = None,
) -> None:
    locale = normalize_invite_email_language(language)
    copy = SAAS_INVITE_COPY.get(locale, SAAS_INVITE_COPY["en"])

    frontend_base = (getattr(settings, "FRONTEND_BASE_URL", "") or "https://goklinik.com").rstrip("/")
    invite_url = f"{frontend_base}/signup/clinic-invite?token={invite_token}"

    safe_greeting = escape(copy["greeting"].format(name=full_name))
    safe_line_1 = escape(copy["line_1"].format(clinic=clinic_name))
    safe_line_2 = escape(copy["line_2"])
    safe_line_3 = escape(copy["line_3"])
    safe_cta = escape(copy["cta"])
    safe_url = escape(invite_url, quote=True)

    text = (
        f'{copy["greeting"].format(name=full_name)}\n\n'
        f'{copy["line_1"].format(clinic=clinic_name)}\n'
        f'{copy["line_2"]}\n'
        f"{invite_url}\n\n"
        f'{copy["line_3"]}'
    )
    html = (
        '<div style="font-family: Arial, sans-serif; color: #1f2937; line-height: 1.5;">'
        f'<p style="margin: 0 0 10px 0;">{safe_greeting}</p>'
        f'<p style="margin: 0 0 10px 0;">{safe_line_1}</p>'
        f'<p style="margin: 0 0 14px 0;">{safe_line_2}</p>'
        f'<p style="margin: 0 0 14px 0;"><a href="{safe_url}" target="_blank" rel="noreferrer" '
        'style="display:inline-block;padding:10px 16px;background:#0D5C73;color:#fff;'
        f'text-decoration:none;border-radius:8px;font-weight:600;">{safe_cta}</a></p>'
        f'<p style="margin: 0;">{safe_line_3}</p>'
        "</div>"
    )

    _send_email(
        recipient=email,
        subject=copy["subject"],
        text=text,
        html=html,
    )
