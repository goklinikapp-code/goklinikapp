from __future__ import annotations

from datetime import time, timedelta
from unittest.mock import patch

from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from apps.appointments.models import Appointment
from apps.chat.models import ChatRoom, PatientAIMessage, TenantAIChatSettings
from apps.chat.views import _build_patient_context
from apps.notifications.models import Notification
from apps.patients.models import Patient
from apps.tenants.models import Tenant
from apps.users.models import GoKlinikUser


class ChatViewsTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Chat T1", slug="chat-t1")
        self.staff = GoKlinikUser.objects.create_user(
            email="staff@chat.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SECRETARY,
        )
        self.clinic_master = GoKlinikUser.objects.create_user(
            email="master@chat.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.surgeon = GoKlinikUser.objects.create_user(
            email="surgeon@chat.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
        )
        self.patient = Patient.objects.create_user(
            email="patient@chat.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="P",
            last_name="C",
        )

        self.other_patient = Patient.objects.create_user(
            email="other@chat.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="O",
            last_name="P",
        )

    def test_room_and_message_success(self):
        self.client.force_authenticate(self.staff)
        room_resp = self.client.post(
            reverse("chat-rooms-list"),
            {
                "room_type": "doctor_patient",
                "patient_id": str(self.patient.id),
            },
            format="json",
        )
        self.assertEqual(room_resp.status_code, status.HTTP_201_CREATED)

        room_id = room_resp.data["id"]
        msg_resp = self.client.post(
            reverse("chat-rooms-messages", kwargs={"pk": room_id}),
            {"content": "Hello", "message_type": "text"},
            format="json",
        )
        self.assertEqual(msg_resp.status_code, status.HTTP_201_CREATED)

    def test_patient_cannot_create_room_for_another_patient(self):
        self.client.force_authenticate(self.patient)
        response = self.client.post(
            reverse("chat-rooms-list"),
            {
                "room_type": "doctor_patient",
                "patient_id": str(self.other_patient.id),
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_patient_message_notifies_staff_and_clinic_master(self):
        room = ChatRoom.objects.create(
            tenant=self.tenant,
            room_type=ChatRoom.RoomTypeChoices.DOCTOR_PATIENT,
            patient=self.patient,
            staff_member=self.staff,
        )
        self.client.force_authenticate(self.patient)
        response = self.client.post(
            reverse("chat-rooms-messages", kwargs={"pk": room.id}),
            {"content": "Preciso de ajuda no pós-op", "message_type": "text"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        recipients = set(
            Notification.objects.filter(notification_type=Notification.NotificationTypeChoices.NEW_MESSAGE).values_list(
                "recipient_id",
                flat=True,
            )
        )
        self.assertIn(self.staff.id, recipients)
        self.assertIn(self.clinic_master.id, recipients)
        self.assertNotIn(self.patient.id, recipients)

    def test_staff_message_notifies_patient(self):
        room = ChatRoom.objects.create(
            tenant=self.tenant,
            room_type=ChatRoom.RoomTypeChoices.DOCTOR_PATIENT,
            patient=self.patient,
            staff_member=self.staff,
        )
        self.client.force_authenticate(self.staff)
        response = self.client.post(
            reverse("chat-rooms-messages", kwargs={"pk": room.id}),
            {"content": "Recebi sua mensagem, vou avaliar.", "message_type": "text"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        self.assertTrue(
            Notification.objects.filter(
                recipient=self.patient,
                notification_type=Notification.NotificationTypeChoices.NEW_MESSAGE,
            ).exists()
        )

    def test_ai_chat_returns_human_mode_when_global_ai_disabled(self):
        TenantAIChatSettings.objects.create(
            tenant=self.tenant,
            ai_enabled=False,
            updated_by=self.clinic_master,
        )
        self.client.force_authenticate(self.patient)
        response = self.client.post(
            reverse("chat-ai-messages"),
            {"content": "Quero falar com alguém da clínica"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data.get("mode"), "human")
        self.assertIsNone(response.data.get("assistant_message"))
        self.assertEqual(len(response.data["messages"]), 1)
        self.assertEqual(response.data["messages"][0]["source"], "patient")

    def test_chat_admin_can_send_human_message_in_ai_conversation(self):
        PatientAIMessage.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            role=PatientAIMessage.RoleChoices.USER,
            source=PatientAIMessage.SourceChoices.PATIENT,
            sender_user=self.patient,
            content="Preciso de ajuda",
        )
        self.client.force_authenticate(self.staff)
        response = self.client.post(
            reverse(
                "chat-admin-ai-conversation-messages",
                kwargs={"patient_id": self.patient.id},
            ),
            {"content": "Claro, vou te orientar agora."},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["source"], "staff")
        self.assertEqual(response.data["role"], "assistant")

    def test_patient_sees_staff_typing_status(self):
        self.client.force_authenticate(self.staff)
        typing_response = self.client.put(
            reverse(
                "chat-admin-ai-patient-typing",
                kwargs={"patient_id": self.patient.id},
            ),
            {"is_typing": True},
            format="json",
        )
        self.assertEqual(typing_response.status_code, status.HTTP_200_OK)

        self.client.force_authenticate(self.patient)
        status_response = self.client.get(reverse("chat-ai-typing-status"))
        self.assertEqual(status_response.status_code, status.HTTP_200_OK)
        self.assertTrue(status_response.data["is_typing"])

    def test_patient_mode_override_disables_ai_for_specific_patient(self):
        self.client.force_authenticate(self.clinic_master)
        mode_response = self.client.put(
            reverse(
                "chat-admin-ai-patient-mode",
                kwargs={"patient_id": self.patient.id},
            ),
            {"force_human": True},
            format="json",
        )
        self.assertEqual(mode_response.status_code, status.HTTP_200_OK)
        self.assertFalse(mode_response.data["effective_ai_enabled"])

        self.client.force_authenticate(self.patient)
        response = self.client.post(
            reverse("chat-ai-messages"),
            {"content": "oi"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data.get("mode"), "human")
        self.assertIsNone(response.data.get("assistant_message"))

    def test_patient_context_only_includes_future_active_appointments(self):
        today = timezone.localdate()
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            appointment_date=today - timedelta(days=1),
            appointment_time=time(10, 0),
            appointment_type=Appointment.AppointmentTypeChoices.POST_OP_7D,
            status=Appointment.StatusChoices.PENDING,
            created_by=self.clinic_master,
        )
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            appointment_date=today + timedelta(days=1),
            appointment_time=time(11, 0),
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            status=Appointment.StatusChoices.PENDING,
            created_by=self.clinic_master,
        )
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            appointment_date=today + timedelta(days=2),
            appointment_time=time(12, 0),
            appointment_type=Appointment.AppointmentTypeChoices.RETURN,
            status=Appointment.StatusChoices.CANCELLED,
            created_by=self.clinic_master,
        )

        context = _build_patient_context(self.patient, "pt")
        self.assertIn(str(today + timedelta(days=1)), context)
        self.assertNotIn(str(today - timedelta(days=1)), context)
        self.assertNotIn(str(today + timedelta(days=2)), context)

    @patch("apps.chat.views.request_chat_completion")
    def test_ai_chat_appointment_question_uses_deterministic_reply(self, request_chat_completion_mock):
        today = timezone.localdate()
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            appointment_date=today - timedelta(days=2),
            appointment_time=time(9, 0),
            appointment_type=Appointment.AppointmentTypeChoices.POST_OP_7D,
            status=Appointment.StatusChoices.PENDING,
            created_by=self.clinic_master,
        )
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            appointment_date=today + timedelta(days=1),
            appointment_time=time(10, 0),
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            status=Appointment.StatusChoices.PENDING,
            created_by=self.clinic_master,
            clinic_location="Lisboa",
        )

        self.client.force_authenticate(self.patient)
        response = self.client.post(
            reverse("chat-ai-messages"),
            {"content": "Tem algum agendamento pra mim?"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        reply = response.data["assistant_message"]["content"]
        future_date_label = (today + timedelta(days=1)).strftime("%d/%m/%Y")
        past_date_label = (today - timedelta(days=2)).strftime("%d/%m/%Y")
        self.assertIn("Próximos agendamentos:", reply)
        self.assertIn(future_date_label, reply)
        self.assertIn("10:00", reply)
        self.assertNotIn(past_date_label, reply)
        request_chat_completion_mock.assert_not_called()

    @patch("apps.chat.views.request_chat_completion")
    def test_greeting_does_not_keep_wrong_appointment_claim_from_llm(self, request_chat_completion_mock):
        request_chat_completion_mock.return_value = (
            "Olá! Você tem dois agendamentos pendentes em abril."
        )

        self.client.force_authenticate(self.patient)
        response = self.client.post(
            reverse("chat-ai-messages"),
            {"content": "oi"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        reply = response.data["assistant_message"]["content"]
        self.assertTrue(
            "Estou aqui para te ajudar" in reply
            or "I am here to help" in reply
        )
        self.assertNotIn("dois agendamentos", reply.lower())
