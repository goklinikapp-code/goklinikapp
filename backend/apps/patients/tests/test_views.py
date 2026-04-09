from __future__ import annotations

from datetime import timedelta

from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from apps.appointments.models import Appointment
from apps.patients.models import DoctorPatientAssignment, Patient
from apps.tenants.models import Tenant, TenantSpecialty
from apps.users.models import GoKlinikUser


class PatientViewSetSurgeonScopeTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Patients Tenant", slug="patients-tenant")

        self.master = GoKlinikUser.objects.create_user(
            email="master@patients.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.surgeon_a = GoKlinikUser.objects.create_user(
            email="surgeon-a@patients.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
            first_name="Surgeon",
            last_name="A",
        )
        self.surgeon_b = GoKlinikUser.objects.create_user(
            email="surgeon-b@patients.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
            first_name="Surgeon",
            last_name="B",
        )

        self.patient_a = Patient.objects.create_user(
            email="patient-a@patients.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Patient",
            last_name="A",
        )
        self.patient_b = Patient.objects.create_user(
            email="patient-b@patients.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Patient",
            last_name="B",
        )

        DoctorPatientAssignment.objects.create(
            patient=self.patient_a,
            doctor=self.surgeon_a,
            assigned_by=self.master,
        )
        DoctorPatientAssignment.objects.create(
            patient=self.patient_b,
            doctor=self.surgeon_b,
            assigned_by=self.master,
        )

    def test_surgeon_list_only_returns_assigned_patients(self):
        self.client.force_authenticate(self.surgeon_a)

        response = self.client.get(reverse("patients-list"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(response.data["results"][0]["id"], str(self.patient_a.id))

    def test_surgeon_cannot_retrieve_other_surgeon_patient(self):
        self.client.force_authenticate(self.surgeon_a)

        response = self.client.get(reverse("patients-detail", args=[self.patient_b.id]))

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_surgeon_can_retrieve_own_assigned_patient(self):
        self.client.force_authenticate(self.surgeon_a)

        response = self.client.get(reverse("patients-detail", args=[self.patient_a.id]))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], str(self.patient_a.id))

    def test_surgeon_my_patients_excludes_unassigned_patient_even_with_appointment(self):
        specialty = TenantSpecialty.objects.create(
            tenant=self.tenant,
            specialty_name="Rinoplastia",
        )
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient_b,
            professional=self.surgeon_a,
            specialty=specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=timezone.localtime().time().replace(
                hour=10,
                minute=0,
                second=0,
                microsecond=0,
            ),
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )
        self.client.force_authenticate(self.surgeon_a)

        response = self.client.get(reverse("patients-my-patients"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item["id"] for item in response.data["results"]}
        self.assertEqual(ids, {str(self.patient_a.id)})

    def test_surgeon_patient_flags_are_scoped_to_logged_doctor(self):
        specialty = TenantSpecialty.objects.create(
            tenant=self.tenant,
            specialty_name="Blefaroplastia",
        )
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient_a,
            professional=self.surgeon_b,
            specialty=specialty,
            appointment_date=timezone.localdate() + timedelta(days=2),
            appointment_time=timezone.localtime().time().replace(
                hour=11,
                minute=0,
                second=0,
                microsecond=0,
            ),
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )
        self.client.force_authenticate(self.surgeon_a)

        response = self.client.get(reverse("patients-list"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        row = response.data["results"][0]
        self.assertEqual(row["id"], str(self.patient_a.id))
        self.assertFalse(row["has_active_appointment"])
