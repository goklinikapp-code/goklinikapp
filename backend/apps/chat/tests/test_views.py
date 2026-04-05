from __future__ import annotations

from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.chat.models import ChatRoom
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
