from __future__ import annotations

from datetime import timedelta

from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from apps.appointments.models import Appointment
from apps.patients.models import DoctorPatientAssignment, Patient
from apps.post_op.models import PostOperatoryCheckin, PostOpChecklist, PostOpJourney, UrgentTicket
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
        self.clinic_master = GoKlinikUser.objects.create_user(
            email="owner@postop.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
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
            status=Appointment.StatusChoices.COMPLETED,
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
        self.other_clinic_master = GoKlinikUser.objects.create_user(
            email="owner@other.com",
            password="pass12345",
            tenant=self.other_tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )

    def test_my_journey_success(self):
        self.client.force_authenticate(self.patient)
        url = reverse("postop-my-journey")
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], str(self.journey.id))

    def test_my_journey_hidden_when_surgery_not_completed(self):
        self.appointment.status = Appointment.StatusChoices.CONFIRMED
        self.appointment.save(update_fields=["status", "updated_at"])

        self.client.force_authenticate(self.patient)
        url = reverse("postop-my-journey")
        response = self.client.get(url)

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_complete_checklist_forbidden_other_tenant(self):
        self.client.force_authenticate(self.other_nurse)
        url = reverse("postop-checklist-complete", kwargs={"checklist_id": self.check.id})
        response = self.client.put(url, {}, format="json")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_update_checklist_success(self):
        self.client.force_authenticate(self.patient)
        url = reverse("postoperatory-checklist-update", kwargs={"checklist_id": self.check.id})
        response = self.client.put(url, {"completed": True}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.check.refresh_from_db()
        self.assertTrue(self.check.is_completed)

    def test_checkin_allows_only_one_submission_per_day(self):
        self.client.force_authenticate(self.patient)
        url = reverse("postoperatory-checkin-create")
        payload = {
            "journey_id": str(self.journey.id),
            "pain_level": 7,
            "has_fever": False,
            "notes": "Tudo bem",
        }

        first_response = self.client.post(url, payload, format="json")
        second_response = self.client.post(url, payload, format="json")

        self.assertEqual(first_response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second_response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(PostOperatoryCheckin.objects.filter(journey=self.journey).count(), 1)

    def test_patient_can_upload_postop_photo_with_heic_mime(self):
        self.client.force_authenticate(self.patient)
        url = reverse("postoperatory-photo-create")
        upload = SimpleUploadedFile(
            "recovery.heic",
            b"fake-heic-content",
            content_type="image/heic",
        )

        response = self.client.post(
            url,
            {
                "journey_id": str(self.journey.id),
                "day": self.journey.current_day,
                "image": upload,
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(self.journey.photos.exists())

    def test_patient_cannot_upload_non_image_postop_photo(self):
        self.client.force_authenticate(self.patient)
        url = reverse("postoperatory-photo-create")
        upload = SimpleUploadedFile(
            "notes.txt",
            b"not-image",
            content_type="text/plain",
        )

        response = self.client.post(
            url,
            {
                "journey_id": str(self.journey.id),
                "day": self.journey.current_day,
                "image": upload,
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_admin_list_returns_alert_fields(self):
        self.client.force_authenticate(self.clinic_master)
        url = reverse("postoperatory-admin-list")
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

        row = response.data[0]
        self.assertEqual(row["patient_id"], str(self.patient.id))
        self.assertIn("has_alert", row)
        self.assertIn("patient_avatar_url", row)
        self.assertIn("last_checkin_date", row)
        self.assertIn("last_pain_level", row)
        self.assertEqual(row["clinical_status"], "delayed")
        self.assertFalse(row["has_alert"])

    def test_admin_list_marks_risk_with_high_pain_or_fever(self):
        PostOperatoryCheckin.objects.create(
            journey=self.journey,
            day=self.journey.current_day,
            pain_level=9,
            has_fever=True,
            notes="Sinais importantes",
        )
        self.client.force_authenticate(self.clinic_master)
        url = reverse("postoperatory-admin-list")
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["clinical_status"], "risk")
        self.assertTrue(response.data[0]["has_alert"])

    def test_admin_detail_returns_journey_snapshot(self):
        checkin = PostOperatoryCheckin.objects.create(
            journey=self.journey,
            day=1,
            pain_level=5,
            has_fever=False,
            notes="Tudo sob controle.",
        )
        self.client.force_authenticate(self.clinic_master)
        url = reverse("postoperatory-admin-detail", kwargs={"patient_id": self.patient.id})
        response = self.client.get(url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["patient_id"], str(self.patient.id))
        self.assertEqual(response.data["journey_id"], str(self.journey.id))
        self.assertEqual(response.data["last_pain_level"], checkin.pain_level)
        self.assertGreaterEqual(len(response.data["checkins"]), 1)
        self.assertGreaterEqual(len(response.data["checklist_by_day"]), 1)
        self.assertGreaterEqual(len(response.data["observations"]), 1)

    def test_admin_detail_forbidden_for_non_supported_role(self):
        self.client.force_authenticate(self.other_nurse)
        url = reverse("postoperatory-admin-detail", kwargs={"patient_id": self.patient.id})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_detail_not_found_for_other_tenant(self):
        self.client.force_authenticate(self.other_clinic_master)
        url = reverse("postoperatory-admin-detail", kwargs={"patient_id": self.patient.id})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_surgeon_list_returns_only_assigned_patients(self):
        other_surgeon = GoKlinikUser.objects.create_user(
            email="surgeon2@postop.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
        )
        other_patient = Patient.objects.create_user(
            email="other-patient@postop.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Other",
            last_name="Patient",
        )
        other_appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=other_patient,
            professional=other_surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate(),
            appointment_time=timezone.localtime().time().replace(hour=10, minute=0, second=0, microsecond=0),
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            status=Appointment.StatusChoices.COMPLETED,
            created_by=self.clinic_master,
        )
        PostOpJourney.objects.create(
            patient=other_patient,
            appointment=other_appointment,
            specialty=self.specialty,
            surgery_date=timezone.localdate() - timedelta(days=1),
            status=PostOpJourney.StatusChoices.ACTIVE,
        )
        DoctorPatientAssignment.objects.create(
            patient=other_patient,
            doctor=other_surgeon,
            assigned_by=self.clinic_master,
        )

        self.client.force_authenticate(self.surgeon)
        response = self.client.get(reverse("postoperatory-admin-list"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item["patient_id"] for item in response.data}
        self.assertIn(str(self.patient.id), ids)
        self.assertNotIn(str(other_patient.id), ids)

    def test_surgeon_can_view_detail_for_assigned_patient(self):
        self.client.force_authenticate(self.surgeon)
        url = reverse("postoperatory-admin-detail", kwargs={"patient_id": self.patient.id})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["patient_id"], str(self.patient.id))

    def test_surgeon_cannot_view_detail_for_unassigned_patient(self):
        other_surgeon = GoKlinikUser.objects.create_user(
            email="surgeon3@postop.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
        )
        other_patient = Patient.objects.create_user(
            email="other-patient-2@postop.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="No",
            last_name="Access",
        )
        other_appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=other_patient,
            professional=other_surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate(),
            appointment_time=timezone.localtime().time().replace(hour=11, minute=0, second=0, microsecond=0),
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            status=Appointment.StatusChoices.COMPLETED,
            created_by=self.clinic_master,
        )
        PostOpJourney.objects.create(
            patient=other_patient,
            appointment=other_appointment,
            specialty=self.specialty,
            surgery_date=timezone.localdate() - timedelta(days=2),
            status=PostOpJourney.StatusChoices.ACTIVE,
        )
        DoctorPatientAssignment.objects.create(
            patient=other_patient,
            doctor=other_surgeon,
            assigned_by=self.clinic_master,
        )

        self.client.force_authenticate(self.surgeon)
        url = reverse("postoperatory-admin-detail", kwargs={"patient_id": other_patient.id})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_patient_can_create_urgent_ticket_with_active_journey(self):
        DoctorPatientAssignment.objects.create(
            patient=self.patient,
            doctor=self.surgeon,
            assigned_by=self.clinic_master,
        )
        self.client.force_authenticate(self.patient)
        url = reverse("urgent-ticket-list-create")
        response = self.client.post(
            url,
            {"message": "Estou com dor intensa e preciso de orientação."},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(UrgentTicket.objects.count(), 1)
        ticket = UrgentTicket.objects.first()
        self.assertIsNotNone(ticket)
        self.assertEqual(ticket.patient_id, self.patient.id)
        self.assertEqual(ticket.doctor_id, self.surgeon.id)
        self.assertEqual(ticket.status, UrgentTicket.StatusChoices.OPEN)
        self.assertEqual(ticket.severity, UrgentTicket.SeverityChoices.HIGH)

    def test_patient_cannot_create_urgent_ticket_without_active_journey(self):
        self.appointment.status = Appointment.StatusChoices.CONFIRMED
        self.appointment.save(update_fields=["status", "updated_at"])

        self.client.force_authenticate(self.patient)
        url = reverse("urgent-ticket-list-create")
        response = self.client.post(
            url,
            {"message": "Preciso de ajuda urgente."},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(UrgentTicket.objects.count(), 0)

    def test_urgent_ticket_list_scoped_for_surgeon(self):
        DoctorPatientAssignment.objects.create(
            patient=self.patient,
            doctor=self.surgeon,
            assigned_by=self.clinic_master,
        )
        UrgentTicket.objects.create(
            patient=self.patient,
            doctor=self.surgeon,
            clinic=self.tenant,
            post_op_journey=self.journey,
            message="Febre e dor alta",
        )
        other_surgeon = GoKlinikUser.objects.create_user(
            email="surgeon-ticket@postop.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
        )
        UrgentTicket.objects.create(
            patient=self.patient,
            doctor=other_surgeon,
            clinic=self.tenant,
            post_op_journey=self.journey,
            message="Mensagem de outro profissional",
        )

        self.client.force_authenticate(self.surgeon)
        response = self.client.get(reverse("urgent-ticket-list-create"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(str(response.data[0]["doctor"]), str(self.surgeon.id))

    def test_clinic_master_can_mark_urgent_ticket_as_resolved(self):
        ticket = UrgentTicket.objects.create(
            patient=self.patient,
            doctor=self.surgeon,
            clinic=self.tenant,
            post_op_journey=self.journey,
            message="Dor forte em repouso.",
        )
        self.client.force_authenticate(self.clinic_master)
        response = self.client.patch(
            reverse("urgent-ticket-status-update", kwargs={"ticket_id": ticket.id}),
            {"status": "resolved"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ticket.refresh_from_db()
        self.assertEqual(ticket.status, UrgentTicket.StatusChoices.RESOLVED)

    def test_admin_detail_includes_urgent_tickets(self):
        UrgentTicket.objects.create(
            patient=self.patient,
            doctor=self.surgeon,
            clinic=self.tenant,
            post_op_journey=self.journey,
            message="Inchaço importante",
            status=UrgentTicket.StatusChoices.OPEN,
        )

        self.client.force_authenticate(self.clinic_master)
        response = self.client.get(
            reverse("postoperatory-admin-detail", kwargs={"patient_id": self.patient.id})
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("urgent_tickets", response.data)
        self.assertEqual(len(response.data["urgent_tickets"]), 1)
        self.assertTrue(response.data["has_open_urgent_ticket"])
