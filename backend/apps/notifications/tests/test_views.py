from __future__ import annotations

from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.notifications.models import Notification
from apps.patients.models import Patient
from apps.tenants.models import Tenant
from apps.users.models import GoKlinikUser


class NotificationViewsTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Notif T1", slug="notif-t1")
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
