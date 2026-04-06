from __future__ import annotations

from datetime import time, timedelta
from unittest.mock import patch

from django.test import TestCase
from django.utils import timezone

from apps.appointments.models import Appointment
from apps.notifications.models import Notification, NotificationLog, NotificationToken
from apps.notifications.services import NotificationService, enviar_notificacao_push, render_notification_template
from apps.patients.models import Patient
from apps.tenants.models import Tenant
from apps.tenants.models import TenantSpecialty
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

    @patch(
        "apps.notifications.services.enviar_notificacao_push",
        return_value={"sent_count": 1, "failed_count": 0, "invalid_tokens": [], "errors": {}},
    )
    def test_send_push_campaign_infers_date_and_procedure_for_manual_template(self, _push_mock):
        NotificationToken.objects.create(
            user=self.patient,
            device_token="token-manual-campaign",
            platform=NotificationToken.PlatformChoices.ANDROID,
            is_active=True,
        )
        appointment_date = timezone.localdate() + timedelta(days=3)
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            appointment_date=appointment_date,
            appointment_time=time(14, 30),
            status=Appointment.StatusChoices.CONFIRMED,
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
        )

        summary = NotificationService.send_push_campaign(
            recipients=[self.patient],
            title_template="Mensagem da clínica",
            body_template="Olá {{name}}, confirmamos sua consulta em {{date}} para {{procedure}}.",
            segment="all_patients",
            event_code="manual_push_campaign",
            create_in_app_notification=False,
        )

        self.assertEqual(summary["sent"], 1)
        log = NotificationLog.objects.filter(user=self.patient, event_code="manual_push_campaign").latest("created_at")
        self.assertIn(appointment_date.strftime("%d/%m/%Y"), log.body)
        self.assertIn("Cirurgia", log.body)

    @patch(
        "apps.notifications.services.enviar_notificacao_push",
        return_value={"sent_count": 1, "failed_count": 0, "invalid_tokens": [], "errors": {}},
    )
    def test_send_push_campaign_uses_friendly_postop_procedure_label(self, _push_mock):
        NotificationToken.objects.create(
            user=self.patient,
            device_token="token-postop-campaign",
            platform=NotificationToken.PlatformChoices.ANDROID,
            is_active=True,
        )
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=time(9, 0),
            status=Appointment.StatusChoices.CONFIRMED,
            appointment_type=Appointment.AppointmentTypeChoices.POST_OP_7D,
        )

        summary = NotificationService.send_push_campaign(
            recipients=[self.patient],
            title_template="Mensagem da clínica",
            body_template="Olá {{name}}, seu procedimento é {{procedure}}.",
            segment="all_patients",
            event_code="manual_push_campaign",
            create_in_app_notification=False,
        )

        self.assertEqual(summary["sent"], 1)
        log = NotificationLog.objects.filter(user=self.patient, event_code="manual_push_campaign").latest("created_at")
        self.assertIn("Pós-operatório (7 dias)", log.body)

    @patch(
        "apps.notifications.services.enviar_notificacao_push",
        return_value={"sent_count": 1, "failed_count": 0, "invalid_tokens": [], "errors": {}},
    )
    def test_send_push_campaign_normalizes_technical_specialty_name(self, _push_mock):
        specialty = TenantSpecialty.objects.create(
            tenant=self.tenant,
            specialty_name="Post-op 7d",
        )
        NotificationToken.objects.create(
            user=self.patient,
            device_token="token-specialty-normalized",
            platform=NotificationToken.PlatformChoices.ANDROID,
            is_active=True,
        )
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            specialty=specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=time(10, 0),
            status=Appointment.StatusChoices.CONFIRMED,
            appointment_type=Appointment.AppointmentTypeChoices.POST_OP_7D,
        )

        summary = NotificationService.send_push_campaign(
            recipients=[self.patient],
            title_template="Mensagem da clínica",
            body_template="Procedimento: {{procedure}}",
            segment="all_patients",
            event_code="manual_push_campaign",
            create_in_app_notification=False,
        )

        self.assertEqual(summary["sent"], 1)
        log = NotificationLog.objects.filter(user=self.patient, event_code="manual_push_campaign").latest("created_at")
        self.assertIn("Pós-operatório (7 dias)", log.body)

    @patch(
        "apps.notifications.services.enviar_notificacao_push",
        return_value={"sent_count": 1, "failed_count": 0, "invalid_tokens": [], "errors": {}},
    )
    def test_send_push_campaign_applies_friendly_fallbacks_when_data_is_missing(self, _push_mock):
        NotificationToken.objects.create(
            user=self.patient_without_token,
            device_token="token-fallback-campaign",
            platform=NotificationToken.PlatformChoices.ANDROID,
            is_active=True,
        )

        summary = NotificationService.send_push_campaign(
            recipients=[self.patient_without_token],
            title_template="Mensagem da clínica",
            body_template="Olá {{name}}, confirmamos sua consulta em {{date}} para {{procedure}} às {{time}}.",
            segment="all_patients",
            event_code="manual_push_campaign",
            create_in_app_notification=False,
        )

        self.assertEqual(summary["sent"], 1)
        log = NotificationLog.objects.filter(
            user=self.patient_without_token,
            event_code="manual_push_campaign",
        ).latest("created_at")
        self.assertIn("data a confirmar", log.body)
        self.assertIn("procedimento a confirmar", log.body)
        self.assertIn("horário a confirmar", log.body)
