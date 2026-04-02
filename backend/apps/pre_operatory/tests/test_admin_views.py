from __future__ import annotations

from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.patients.models import DoctorPatientAssignment, Patient
from apps.pre_operatory.models import PreOperatory
from apps.tenants.models import Tenant
from apps.users.models import GoKlinikUser


class PreOperatoryAdminViewsTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Clinic 1", slug="clinic-1")
        self.other_tenant = Tenant.objects.create(name="Clinic 2", slug="clinic-2")

        self.clinic_master = GoKlinikUser.objects.create_user(
            email="master@clinic.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.secretary = GoKlinikUser.objects.create_user(
            email="secretary@clinic.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SECRETARY,
        )
        self.surgeon = GoKlinikUser.objects.create_user(
            email="surgeon@clinic.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
            first_name="Doc",
            last_name="One",
        )
        self.other_surgeon = GoKlinikUser.objects.create_user(
            email="surgeon-2@clinic.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
            first_name="Doc",
            last_name="Two",
        )
        self.patient = Patient.objects.create_user(
            email="patient@clinic.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Pat",
            last_name="One",
        )
        self.pre_operatory = PreOperatory.objects.create(
            patient=self.patient,
            tenant=self.tenant,
            allergies="none",
            status=PreOperatory.StatusChoices.PENDING,
        )

        self.other_patient = Patient.objects.create_user(
            email="other-patient@clinic.com",
            password="pass12345",
            tenant=self.other_tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Other",
            last_name="Patient",
        )
        PreOperatory.objects.create(
            patient=self.other_patient,
            tenant=self.other_tenant,
            allergies="none",
            status=PreOperatory.StatusChoices.PENDING,
        )

    def test_clinic_master_can_list_pre_operatory_for_own_tenant(self):
        self.client.force_authenticate(self.clinic_master)

        response = self.client.get(reverse("api-pre-operatory"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["id"], str(self.pre_operatory.id))

    def test_clinic_master_can_filter_pre_operatory_by_status(self):
        self.pre_operatory.status = PreOperatory.StatusChoices.IN_REVIEW
        self.pre_operatory.save(update_fields=["status"])

        self.client.force_authenticate(self.clinic_master)
        response = self.client.get(
            reverse("api-pre-operatory"),
            {"status": PreOperatory.StatusChoices.IN_REVIEW},
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["status"], PreOperatory.StatusChoices.IN_REVIEW)

    def test_default_admin_list_only_returns_pending_and_in_review(self):
        approved_patient = Patient.objects.create_user(
            email="approved@clinic.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Approved",
            last_name="Patient",
        )
        rejected_patient = Patient.objects.create_user(
            email="rejected@clinic.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Rejected",
            last_name="Patient",
        )
        PreOperatory.objects.create(
            patient=approved_patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.APPROVED,
        )
        PreOperatory.objects.create(
            patient=rejected_patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.REJECTED,
        )

        self.client.force_authenticate(self.clinic_master)
        response = self.client.get(reverse("api-pre-operatory"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["status"], PreOperatory.StatusChoices.PENDING)

    def test_admin_can_explicitly_filter_approved(self):
        approved_patient = Patient.objects.create_user(
            email="approved-filter@clinic.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Approved",
            last_name="Filter",
        )
        approved = PreOperatory.objects.create(
            patient=approved_patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.APPROVED,
        )

        self.client.force_authenticate(self.clinic_master)
        response = self.client.get(
            reverse("api-pre-operatory"),
            {"status": PreOperatory.StatusChoices.APPROVED},
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["id"], str(approved.id))

    def test_clinic_master_can_update_status_notes_and_assigned_doctor(self):
        self.client.force_authenticate(self.clinic_master)

        response = self.client.put(
            reverse("api-pre-operatory-detail", kwargs={"pre_operatory_id": self.pre_operatory.id}),
            {
                "status": PreOperatory.StatusChoices.APPROVED,
                "notes": "Paciente apto para cirurgia.",
                "assigned_doctor": str(self.surgeon.id),
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.pre_operatory.refresh_from_db()
        self.assertEqual(self.pre_operatory.status, PreOperatory.StatusChoices.APPROVED)
        self.assertEqual(self.pre_operatory.notes, "Paciente apto para cirurgia.")
        self.assertEqual(str(self.pre_operatory.assigned_doctor_id), str(self.surgeon.id))

        assignment = DoctorPatientAssignment.objects.filter(patient=self.patient).first()
        self.assertIsNotNone(assignment)
        self.assertEqual(str(assignment.doctor_id), str(self.surgeon.id))
        self.assertEqual(str(assignment.assigned_by_id), str(self.clinic_master.id))

    def test_patient_cannot_update_status(self):
        self.client.force_authenticate(self.patient)

        response = self.client.put(
            reverse("api-pre-operatory-detail", kwargs={"pre_operatory_id": self.pre_operatory.id}),
            {"status": PreOperatory.StatusChoices.APPROVED},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.pre_operatory.refresh_from_db()
        self.assertEqual(self.pre_operatory.status, PreOperatory.StatusChoices.PENDING)

    def test_non_clinic_master_cannot_list_or_update_admin_fields(self):
        self.client.force_authenticate(self.secretary)

        list_response = self.client.get(reverse("api-pre-operatory"))
        self.assertEqual(list_response.status_code, status.HTTP_403_FORBIDDEN)

        update_response = self.client.put(
            reverse("api-pre-operatory-detail", kwargs={"pre_operatory_id": self.pre_operatory.id}),
            {"status": PreOperatory.StatusChoices.IN_REVIEW},
            format="json",
        )
        self.assertEqual(update_response.status_code, status.HTTP_403_FORBIDDEN)

    def test_assigned_surgeon_can_view_patient_pre_operatory(self):
        DoctorPatientAssignment.objects.create(
            patient=self.patient,
            doctor=self.surgeon,
            assigned_by=self.clinic_master,
        )
        self.client.force_authenticate(self.surgeon)

        response = self.client.get(
            reverse("api-pre-operatory-patient", kwargs={"patient_id": self.patient.id})
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], str(self.pre_operatory.id))
        self.assertIn("smokes", response.data)
        self.assertIn("drinks_alcohol", response.data)
        self.assertFalse(response.data["smokes"])
        self.assertFalse(response.data["drinks_alcohol"])

    def test_unassigned_surgeon_cannot_view_patient_pre_operatory(self):
        DoctorPatientAssignment.objects.create(
            patient=self.patient,
            doctor=self.surgeon,
            assigned_by=self.clinic_master,
        )
        self.client.force_authenticate(self.other_surgeon)

        response = self.client.get(
            reverse("api-pre-operatory-patient", kwargs={"patient_id": self.patient.id})
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
