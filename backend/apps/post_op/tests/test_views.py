from __future__ import annotations

from datetime import timedelta

from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from apps.appointments.models import Appointment
from apps.patients.models import Patient
from apps.post_op.models import PostOpChecklist, PostOpJourney
from apps.tenants.models import Tenant, TenantSpecialty
from apps.users.models import GoKlinikUser


class PostOpViewsTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="T1", slug="postop-t1")
        self.specialty = TenantSpecialty.objects.create(tenant=self.tenant, specialty_name="Rino")

        self.surgeon = GoKlinikUser.objects.create_user(
            email="surgeon@postop.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
        )
        self.patient = Patient.objects.create_user(
            email="patient@postop.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Pat",
            last_name="One",
        )

        self.appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate(),
            appointment_time=timezone.localtime().time().replace(hour=9, minute=0, second=0, microsecond=0),
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            status=Appointment.StatusChoices.CONFIRMED,
            created_by=self.surgeon,
        )

        self.journey = PostOpJourney.objects.create(
            patient=self.patient,
            appointment=self.appointment,
            specialty=self.specialty,
            surgery_date=timezone.localdate() - timedelta(days=3),
            status=PostOpJourney.StatusChoices.ACTIVE,
        )
        self.check = PostOpChecklist.objects.create(
            journey=self.journey,
            day_number=3,
            item_text="Take medication",
        )

        self.other_tenant = Tenant.objects.create(name="T2", slug="postop-t2")
        self.other_nurse = GoKlinikUser.objects.create_user(
            email="nurse@other.com",
            password="pass12345",
            tenant=self.other_tenant,
            role=GoKlinikUser.RoleChoices.NURSE,
        )

    def test_my_journey_success(self):
        self.client.force_authenticate(self.patient)
        url = reverse("postop-my-journey")
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], str(self.journey.id))

    def test_complete_checklist_forbidden_other_tenant(self):
        self.client.force_authenticate(self.other_nurse)
        url = reverse("postop-checklist-complete", kwargs={"checklist_id": self.check.id})
        response = self.client.put(url, {}, format="json")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
