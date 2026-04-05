from __future__ import annotations

from datetime import timedelta
from unittest.mock import patch

from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from apps.notifications.models import (
    Notification,
    NotificationLog,
    NotificationTemplate,
    NotificationToken,
    NotificationWorkflow,
    ScheduledNotification,
)
from apps.patients.models import Patient
from apps.tenants.models import Tenant
from apps.users.models import GoKlinikUser


class NotificationViewsTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Notif T1", slug="notif-t1")
        self.other_tenant = Tenant.objects.create(name="Notif T2", slug="notif-t2")
        self.master = GoKlinikUser.objects.create_user(
            email="master@notif.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.patient = Patient.objects.create_user(
            email="patient@notif.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="N",
            last_name="P",
        )

        self.notification = Notification.objects.create(
            tenant=self.tenant,
            recipient=self.patient,
            title="Test",
            body="Body",
            notification_type=Notification.NotificationTypeChoices.SYSTEM,
        )

    def test_templates_create_and_update(self):
        self.client.force_authenticate(self.master)
        create_response = self.client.post(
            reverse("notifications-templates"),
            {
                "code": "lembrete_consulta",
                "title_template": "Lembrete para {{name}}",
                "body_template": "Olá {{name}}, sua consulta é {{date}}.",
                "is_active": True,
            },
            format="json",
        )
        self.assertEqual(create_response.status_code, status.HTTP_201_CREATED)
        template_id = create_response.data["id"]

        patch_response = self.client.patch(
            reverse("notifications-template-detail", kwargs={"template_id": template_id}),
            {
                "body_template": "Olá {{name}}, sua consulta está marcada para {{date}}.",
                "is_active": False,
            },
            format="json",
        )
        self.assertEqual(patch_response.status_code, status.HTTP_200_OK)
        self.assertEqual(patch_response.data["is_active"], False)

    def test_templates_list_filters_by_tenant(self):
        NotificationTemplate.objects.create(
            tenant=self.tenant,
            code="template_t1",
            title_template="T1",
            body_template="Mensagem T1",
            is_active=True,
        )
        NotificationTemplate.objects.create(
            tenant=self.other_tenant,
            code="template_t2",
            title_template="T2",
            body_template="Mensagem T2",
            is_active=True,
        )
        self.client.force_authenticate(self.master)
        response = self.client.get(reverse("notifications-templates"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["code"], "template_t1")

    def test_register_token_success(self):
        self.client.force_authenticate(self.patient)
        response = self.client.post(
            reverse("notifications-register-token"),
            {"device_token": "token-123", "platform": "ios", "is_active": True},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_broadcast_forbidden_for_patient(self):
        self.client.force_authenticate(self.patient)
        response = self.client.post(
            reverse("notifications-admin-broadcast"),
            {"title": "Promo", "body": "Hello", "send_to_all": True},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    @patch(
        "apps.notifications.services.enviar_notificacao_push",
        return_value={"sent_count": 1, "failed_count": 0, "invalid_tokens": [], "errors": {}},
    )
    def test_broadcast_push_campaign_creates_notification_log(self, _push_mock):
        NotificationToken.objects.create(
            user=self.patient,
            device_token="token-view-1",
            platform=NotificationToken.PlatformChoices.IOS,
            is_active=True,
        )

        self.client.force_authenticate(self.master)
        response = self.client.post(
            reverse("notifications-admin-broadcast"),
            {
                "title": "Campanha",
                "body": "Olá {{name}}, temos novidades.",
                "channel": "push",
                "segment": "all_patients",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["total_recipients"], 1)
        self.assertEqual(response.data["sent"], 1)
        self.assertEqual(NotificationLog.objects.count(), 1)
        self.assertEqual(response.data["campaign_status"], "success")

    @patch("apps.notifications.views.NotificationService.send_push_campaign", side_effect=Exception("boom"))
    def test_broadcast_returns_structured_error_instead_of_generic_500(self, _send_mock):
        NotificationToken.objects.create(
            user=self.patient,
            device_token="token-view-2",
            platform=NotificationToken.PlatformChoices.IOS,
            is_active=True,
        )
        self.client.force_authenticate(self.master)
        response = self.client.post(
            reverse("notifications-admin-broadcast"),
            {
                "title": "Campanha",
                "body": "Olá {{name}}, temos novidades.",
                "channel": "push",
                "segment": "all_patients",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertEqual(response.data["code"], "push_campaign_error")
        self.assertEqual(response.data["campaign_status"], "error")

    def test_admin_logs_endpoint_requires_clinic_master(self):
        self.client.force_authenticate(self.patient)
        response = self.client.get(reverse("notifications-admin-logs"))
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_broadcast_returns_no_recipients_when_segment_has_no_active_tokens(self):
        self.client.force_authenticate(self.master)
        response = self.client.post(
            reverse("notifications-admin-broadcast"),
            {
                "title": "Campanha",
                "body": "Olá {{name}}, teste sem token.",
                "channel": "push",
                "segment": "all_patients",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["campaign_status"], "no_recipients")
        self.assertEqual(response.data["total_recipients"], 0)

    @patch(
        "apps.notifications.services.enviar_notificacao_push",
        return_value={"sent_count": 1, "failed_count": 0, "invalid_tokens": [], "errors": {}},
    )
    def test_broadcast_to_individual_patient(self, _push_mock):
        NotificationToken.objects.create(
            user=self.patient,
            device_token="token-individual-1",
            platform=NotificationToken.PlatformChoices.IOS,
            is_active=True,
        )
        self.client.force_authenticate(self.master)
        response = self.client.post(
            reverse("notifications-admin-broadcast"),
            {
                "target_mode": "patient",
                "patient_id": str(self.patient.id),
                "title": "Mensagem",
                "body": "Olá {{name}}, envio individual.",
                "channel": "push",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["campaign_status"], "success")
        self.assertEqual(response.data["total_recipients"], 1)

    def test_broadcast_to_individual_patient_without_push_token_returns_no_recipients(self):
        self.client.force_authenticate(self.master)
        response = self.client.post(
            reverse("notifications-admin-broadcast"),
            {
                "target_mode": "patient",
                "patient_id": str(self.patient.id),
                "title": "Mensagem",
                "body": "Olá {{name}}, envio individual.",
                "channel": "push",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["campaign_status"], "no_recipients")
        self.assertEqual(response.data["total_recipients"], 0)

    def test_recipient_search_returns_push_status(self):
        NotificationToken.objects.create(
            user=self.patient,
            device_token="token-search-1",
            platform=NotificationToken.PlatformChoices.IOS,
            is_active=True,
        )
        self.client.force_authenticate(self.master)
        response = self.client.get(
            reverse("notifications-admin-recipient-search"),
            {"q": "patient"},
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        payload = response.data
        results = payload.get("results", payload)
        self.assertGreaterEqual(len(results), 1)
        self.assertTrue(results[0]["has_active_push_token"])
        self.assertEqual(results[0]["active_push_tokens"], 1)

    def test_admin_logs_endpoint_returns_tenant_logs(self):
        NotificationLog.objects.create(
            tenant=self.tenant,
            user=self.patient,
            title="Push",
            body="Mensagem",
            channel=NotificationLog.ChannelChoices.PUSH,
            status=NotificationLog.StatusChoices.SENT,
            event_code="manual_push_campaign",
            segment="all_patients",
        )

        self.client.force_authenticate(self.master)
        response = self.client.get(reverse("notifications-admin-logs"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        payload = response.data
        results = payload.get("results", payload)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["event_code"], "manual_push_campaign")

    def test_admin_logs_delete_clears_only_errors_by_default(self):
        NotificationLog.objects.create(
            tenant=self.tenant,
            user=self.patient,
            title="Erro",
            body="Mensagem",
            channel=NotificationLog.ChannelChoices.PUSH,
            status=NotificationLog.StatusChoices.ERROR,
            event_code="manual_push_campaign",
            segment="all_patients",
            error_message="Firebase messaging unavailable.",
        )
        NotificationLog.objects.create(
            tenant=self.tenant,
            user=self.patient,
            title="Enviado",
            body="Mensagem",
            channel=NotificationLog.ChannelChoices.PUSH,
            status=NotificationLog.StatusChoices.SENT,
            event_code="manual_push_campaign",
            segment="all_patients",
        )

        self.client.force_authenticate(self.master)
        response = self.client.delete(reverse("notifications-admin-logs"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(response.data["deleted_count"], 1)
        self.assertEqual(
            NotificationLog.objects.filter(status=NotificationLog.StatusChoices.SENT).count(),
            1,
        )

    def test_workflows_get_creates_defaults(self):
        self.client.force_authenticate(self.master)
        response = self.client.get(reverse("notifications-workflows"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(response.data), 3)
        self.assertTrue(
            NotificationWorkflow.objects.filter(
                tenant=self.tenant,
                trigger_type=NotificationWorkflow.TriggerTypeChoices.APPOINTMENT_CREATED,
            ).exists()
        )

    def test_workflow_can_be_created_and_toggled(self):
        template = NotificationTemplate.objects.create(
            tenant=self.tenant,
            code="wf-custom-template",
            title_template="Titulo {{name}}",
            body_template="Corpo {{name}}",
            is_active=True,
        )
        self.client.force_authenticate(self.master)
        create_response = self.client.post(
            reverse("notifications-workflows"),
            {
                "name": "Meu workflow",
                "is_active": True,
                "trigger_type": "reminder_before",
                "trigger_offset": "48h",
                "template": str(template.id),
            },
            format="json",
        )
        self.assertEqual(create_response.status_code, status.HTTP_201_CREATED)
        workflow_id = create_response.data["id"]

        patch_response = self.client.patch(
            reverse("notifications-workflow-detail", kwargs={"workflow_id": workflow_id}),
            {"is_active": False},
            format="json",
        )
        self.assertEqual(patch_response.status_code, status.HTTP_200_OK)
        self.assertEqual(patch_response.data["is_active"], False)

    def test_workflow_rejects_template_from_other_tenant(self):
        foreign_template = NotificationTemplate.objects.create(
            tenant=self.other_tenant,
            code="foreign-template",
            title_template="Titulo {{name}}",
            body_template="Corpo {{name}}",
            is_active=True,
        )
        self.client.force_authenticate(self.master)
        response = self.client.post(
            reverse("notifications-workflows"),
            {
                "name": "Workflow inválido",
                "is_active": True,
                "trigger_type": "reminder_before",
                "trigger_offset": "24h",
                "template": str(foreign_template.id),
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("template", response.data)

    @patch("apps.notifications.tasks.run_scheduled_notification_task.apply_async")
    def test_schedule_notification_create(self, apply_async_mock):
        class _Result:
            id = "task-123"

        apply_async_mock.return_value = _Result()
        self.client.force_authenticate(self.master)
        run_at = timezone.now() + timedelta(hours=2)
        response = self.client.post(
            reverse("notifications-admin-scheduled"),
            {
                "run_at": run_at.isoformat(),
                "segment": "all_patients",
                "title": "Campanha agendada",
                "body": "Olá {{name}}",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(ScheduledNotification.objects.count(), 1)
        item = ScheduledNotification.objects.first()
        self.assertEqual(item.status, ScheduledNotification.StatusChoices.PENDING)
        self.assertEqual(item.celery_task_id, "task-123")
