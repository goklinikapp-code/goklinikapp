from __future__ import annotations

from datetime import time, timedelta

from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from apps.appointments.models import Appointment
from apps.patients.models import Patient
from apps.post_op.models import PostOpJourney
from apps.pre_operatory.models import PreOperatory, PreOperatoryFile
from apps.tenants.models import Tenant, TenantSpecialty
from apps.users.models import GoKlinikUser


class PreOperatoryPatientViewsTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Clinic 1", slug="clinic-1")

        self.clinic_master = GoKlinikUser.objects.create_user(
            email="master@clinic.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.patient = Patient.objects.create_user(
            email="patient@clinic.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Pat",
            last_name="One",
        )
        self.procedure = TenantSpecialty.objects.create(
            tenant=self.tenant,
            specialty_name="Rinoplastia",
            description="Correção estética e funcional do nariz.",
            is_active=True,
        )

    def test_me_returns_404_when_patient_has_not_submitted_pre_operatory(self):
        self.client.force_authenticate(self.patient)
        response = self.client.get(reverse("api-pre-operatory-me"))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_create_requires_height_and_weight(self):
        self.client.force_authenticate(self.patient)

        response = self.client.post(
            reverse("api-pre-operatory"),
            {"allergies": "none"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("height", response.data)
        self.assertIn("weight", response.data)

    def test_create_requires_procedure_selection(self):
        self.client.force_authenticate(self.patient)

        response = self.client.post(
            reverse("api-pre-operatory"),
            {"height": 1.70, "weight": 70},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("procedure", response.data)

    def test_patient_cannot_edit_record_after_clinic_review_started(self):
        pre_operatory = PreOperatory.objects.create(
            patient=self.patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.IN_REVIEW,
            height=1.72,
            weight=72.0,
        )
        self.client.force_authenticate(self.patient)

        response = self.client.put(
            reverse(
                "api-pre-operatory-detail",
                kwargs={"pre_operatory_id": pre_operatory.id},
            ),
            {"allergies": "changed"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("detail", response.data)

    def test_patient_update_from_rejected_reopens_triage_as_pending(self):
        pre_operatory = PreOperatory.objects.create(
            patient=self.patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.REJECTED,
            allergies="old",
            height=1.7,
            weight=70,
        )
        self.client.force_authenticate(self.patient)

        response = self.client.put(
            reverse(
                "api-pre-operatory-detail",
                kwargs={"pre_operatory_id": pre_operatory.id},
            ),
            {"allergies": "updated by patient"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        pre_operatory.refresh_from_db()
        self.assertEqual(pre_operatory.status, PreOperatory.StatusChoices.PENDING)
        self.assertEqual(pre_operatory.allergies, "updated by patient")

    def test_me_prefers_active_record_by_created_at_instead_of_last_updated_at(self):
        rejected = PreOperatory.objects.create(
            patient=self.patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.REJECTED,
            notes="old",
            height=1.8,
            weight=80,
        )
        pending = PreOperatory.objects.create(
            patient=self.patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.PENDING,
            notes="current",
            height=1.81,
            weight=81,
        )
        rejected.notes = "recently edited by clinic"
        rejected.save(update_fields=["notes", "updated_at"])

        self.client.force_authenticate(self.patient)
        response = self.client.get(reverse("api-pre-operatory-me"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], str(pending.id))

    def test_me_exposes_clinic_notes_to_patient_app(self):
        pre_operatory = PreOperatory.objects.create(
            patient=self.patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.REJECTED,
            notes="Ajustar exames laboratoriais e reenviar.",
            height=1.72,
            weight=72,
        )

        self.client.force_authenticate(self.patient)
        response = self.client.get(reverse("api-pre-operatory-me"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], str(pre_operatory.id))
        self.assertEqual(
            response.data["notes"],
            "Ajustar exames laboratoriais e reenviar.",
        )

    def test_create_new_cycle_is_blocked_until_postop_is_completed(self):
        PreOperatory.objects.create(
            patient=self.patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.APPROVED,
            approved_at=timezone.now() - timedelta(days=10),
            height=1.73,
            weight=73,
        )
        surgery = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            appointment_date=timezone.localdate() - timedelta(days=6),
            appointment_time=time(10, 0),
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            status=Appointment.StatusChoices.COMPLETED,
        )
        PostOpJourney.objects.create(
            patient=self.patient,
            clinic=self.tenant,
            appointment=surgery,
            surgery_date=surgery.appointment_date,
            status=PostOpJourney.StatusChoices.ACTIVE,
        )

        self.client.force_authenticate(self.patient)

        response = self.client.post(
            reverse("api-pre-operatory"),
            {"height": 1.7, "weight": 70},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("detail", response.data)

    def test_create_new_cycle_allowed_after_completed_postop(self):
        approved = PreOperatory.objects.create(
            patient=self.patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.APPROVED,
            approved_at=timezone.now() - timedelta(days=5),
            height=1.73,
            weight=73,
        )
        surgery = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            appointment_date=timezone.localdate(),
            appointment_time=time(10, 0),
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            status=Appointment.StatusChoices.COMPLETED,
        )
        PostOpJourney.objects.create(
            patient=self.patient,
            clinic=self.tenant,
            appointment=surgery,
            surgery_date=surgery.appointment_date,
            status=PostOpJourney.StatusChoices.COMPLETED,
        )

        self.client.force_authenticate(self.patient)
        response = self.client.post(
            reverse("api-pre-operatory"),
            {
                "height": 1.76,
                "weight": 76,
                "procedure": str(self.procedure.id),
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertNotEqual(response.data["id"], str(approved.id))
        self.assertEqual(str(response.data["procedure"]), str(self.procedure.id))
        self.assertEqual(response.data["procedure_name"], self.procedure.specialty_name)
        self.assertEqual(response.data["procedure_description"], self.procedure.description)

    def test_create_new_cycle_auto_completes_expired_postop_before_unlocking(self):
        approved = PreOperatory.objects.create(
            patient=self.patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.APPROVED,
            approved_at=timezone.now() - timedelta(days=120),
            height=1.7,
            weight=70,
        )
        surgery = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            appointment_date=timezone.localdate() - timedelta(days=100),
            appointment_time=time(8, 0),
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            status=Appointment.StatusChoices.COMPLETED,
        )
        journey = PostOpJourney.objects.create(
            patient=self.patient,
            clinic=self.tenant,
            appointment=surgery,
            surgery_date=surgery.appointment_date,
            start_date=timezone.localdate() - timedelta(days=100),
            end_date=timezone.localdate() - timedelta(days=10),
            status=PostOpJourney.StatusChoices.ACTIVE,
        )

        self.client.force_authenticate(self.patient)
        response = self.client.post(
            reverse("api-pre-operatory"),
            {
                "height": 1.75,
                "weight": 75,
                "procedure": str(self.procedure.id),
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertNotEqual(response.data["id"], str(approved.id))
        journey.refresh_from_db()
        self.assertEqual(journey.status, PostOpJourney.StatusChoices.COMPLETED)

    def test_patient_cannot_delete_pre_operatory_photo_when_status_not_editable(self):
        pre_operatory = PreOperatory.objects.create(
            patient=self.patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.IN_REVIEW,
            height=1.7,
            weight=70,
        )
        file_row = PreOperatoryFile.objects.create(
            pre_operatory=pre_operatory,
            file_url="https://example.com/pre-op/file.jpg",
            type=PreOperatoryFile.FileTypeChoices.PHOTO,
        )
        self.client.force_authenticate(self.patient)

        response = self.client.delete(
            reverse("api-pre-operatory-file-detail", kwargs={"file_id": file_row.id})
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertTrue(
            PreOperatoryFile.objects.filter(id=file_row.id).exists()
        )

    def test_patient_can_delete_pre_operatory_photo_while_pending(self):
        pre_operatory = PreOperatory.objects.create(
            patient=self.patient,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.PENDING,
            height=1.7,
            weight=70,
        )
        file_row = PreOperatoryFile.objects.create(
            pre_operatory=pre_operatory,
            file_url="https://example.com/pre-op/file.jpg",
            type=PreOperatoryFile.FileTypeChoices.PHOTO,
        )
        self.client.force_authenticate(self.patient)

        response = self.client.delete(
            reverse("api-pre-operatory-file-detail", kwargs={"file_id": file_row.id})
        )

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(
            PreOperatoryFile.objects.filter(id=file_row.id).exists()
        )
