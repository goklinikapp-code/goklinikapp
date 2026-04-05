from __future__ import annotations

from unittest.mock import patch

from django.test import TestCase

from apps.notifications.models import Notification, NotificationLog, NotificationToken
from apps.notifications.services import NotificationService, enviar_notificacao_push, render_notification_template
from apps.patients.models import Patient
from apps.tenants.models import Tenant
from apps.users.models import GoKlinikUser


class _FakeInvalidMessaging:
    class Notification:
        def __init__(self, title: str, body: str):
            self.title = title
            self.body = body

    class Message:
        def __init__(self, token: str, notification, data):
            self.token = token
            self.notification = notification
            self.data = data

    @staticmethod
    def send(message):  # noqa: ANN001
        raise Exception("Requested entity was not found.")


class NotificationServicesTestCase(TestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Notif Service T1", slug="notif-service-t1")
        self.patient = Patient.objects.create_user(
            email="patient-service@notif.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Ana",
            last_name="Paciente",
        )
        self.patient_without_token = Patient.objects.create_user(
            email="no-token@notif.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Sem",
            last_name="Token",
        )

    def test_render_notification_template_replaces_variables(self):
        text = render_notification_template(
            "Olá {{name}}, sua consulta é {{date}} para {{procedure}}.",
            {"name": "Ana", "date": "10/04/2026", "procedure": "Rinoplastia"},
        )
        self.assertEqual(
            text,
            "Olá Ana, sua consulta é 10/04/2026 para Rinoplastia.",
        )

    def test_enviar_notificacao_push_disables_invalid_tokens(self):
        token_value = "invalid-token-123"
        NotificationToken.objects.create(
            user=self.patient,
            device_token=token_value,
            platform=NotificationToken.PlatformChoices.IOS,
            is_active=True,
        )

        with patch.object(
            NotificationService,
            "_get_firebase_messaging",
            return_value=_FakeInvalidMessaging(),
        ):
            result = enviar_notificacao_push(
                tokens=[token_value],
                titulo="Teste",
                corpo="Mensagem",
            )

        self.assertEqual(result["sent_count"], 0)
        self.assertEqual(result["failed_count"], 1)
        self.assertIn(token_value, result["invalid_tokens"])

        token_row = NotificationToken.objects.get(device_token=token_value, user=self.patient)
        self.assertFalse(token_row.is_active)

    def test_send_push_to_user_uses_idempotency_key(self):
        NotificationToken.objects.create(
            user=self.patient,
            device_token="token-abc",
            platform=NotificationToken.PlatformChoices.IOS,
            is_active=True,
        )

        fake_result = {
            "sent_count": 1,
            "failed_count": 0,
            "invalid_tokens": [],
            "errors": {},
        }

        with patch("apps.notifications.services.enviar_notificacao_push", return_value=fake_result) as push_mock:
            NotificationService.send_push_to_user(
                user=self.patient,
                title="Título",
                body="Corpo",
                idempotency_key="appointment_confirmation:test-id",
                event_code="appointment_confirmation",
                create_in_app_notification=True,
            )
            NotificationService.send_push_to_user(
                user=self.patient,
                title="Título",
                body="Corpo",
                idempotency_key="appointment_confirmation:test-id",
                event_code="appointment_confirmation",
                create_in_app_notification=True,
            )

        self.assertEqual(push_mock.call_count, 1)
        self.assertEqual(NotificationLog.objects.count(), 1)
        self.assertEqual(
            NotificationLog.objects.first().status,  # type: ignore[union-attr]
            NotificationLog.StatusChoices.SENT,
        )
        self.assertEqual(Notification.objects.count(), 1)

    def test_segment_recipient_query_can_filter_only_users_with_active_tokens(self):
        NotificationToken.objects.create(
            user=self.patient,
            device_token="token-valid",
            platform=NotificationToken.PlatformChoices.IOS,
            is_active=True,
        )

        recipients = list(
            NotificationService.resolve_recipients_for_segment(
                tenant_id=self.tenant.id,
                segment="all_patients",
                require_active_tokens=True,
            )
        )
        self.assertEqual(len(recipients), 1)
        self.assertEqual(recipients[0].id, self.patient.id)

    def test_send_push_campaign_handles_user_level_exception_and_keeps_processing(self):
        another_patient = Patient.objects.create_user(
            email="patient-2@notif.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Outra",
            last_name="Pessoa",
        )
        NotificationToken.objects.create(
            user=self.patient,
            device_token="token-1",
            platform=NotificationToken.PlatformChoices.IOS,
            is_active=True,
        )
        NotificationToken.objects.create(
            user=another_patient,
            device_token="token-2",
            platform=NotificationToken.PlatformChoices.IOS,
            is_active=True,
        )

        def _send_side_effect(**kwargs):  # noqa: ANN003
            if kwargs["user"].id == self.patient.id:
                raise RuntimeError("force-user-error")
            return NotificationLog.objects.create(
                tenant=self.tenant,
                user=kwargs["user"],
                title=kwargs["title"],
                body=kwargs["body"],
                channel=NotificationLog.ChannelChoices.PUSH,
                status=NotificationLog.StatusChoices.SENT,
                event_code=kwargs.get("event_code", ""),
                segment=kwargs.get("segment", ""),
            )

        with patch.object(NotificationService, "send_push_to_user", side_effect=_send_side_effect):
            summary = NotificationService.send_push_campaign(
                recipients=[self.patient, another_patient],
                title_template="Olá {{name}}",
                body_template="Mensagem",
                segment="all_patients",
                event_code="manual_push_campaign",
                create_in_app_notification=False,
            )

        self.assertEqual(summary["total_recipients"], 2)
        self.assertEqual(summary["sent"], 1)
        self.assertEqual(summary["error"], 1)
