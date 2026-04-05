from __future__ import annotations

from datetime import time, timedelta
from unittest.mock import patch

from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from apps.appointments.models import Appointment, ProfessionalAvailability
from apps.notifications.models import Notification
from apps.patients.models import DoctorPatientAssignment, Patient
from apps.post_op.models import PostOpJourney
from apps.tenants.models import Tenant, TenantSpecialty
from apps.users.models import GoKlinikUser


class AppointmentViewsTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="T1", slug="t1")
        self.specialty = TenantSpecialty.objects.create(tenant=self.tenant, specialty_name="Rino")

        self.master = GoKlinikUser.objects.create_user(
            email="master@app.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.surgeon = GoKlinikUser.objects.create_user(
            email="surgeon@app.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
        )
        self.surgeon_2 = GoKlinikUser.objects.create_user(
            email="surgeon2@app.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
        )
        self.patient = Patient.objects.create_user(
            email="patient@app.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Pat",
            last_name="One",
        )

    @staticmethod
    def _next_weekday_date(weekday: int):
        date = timezone.localdate() + timedelta(days=1)
        while date.weekday() != weekday:
            date += timedelta(days=1)
        return date

    def test_create_appointment_success(self):
        self.client.force_authenticate(self.master)
        url = reverse("appointments-list")
        date = timezone.localdate() + timedelta(days=1)

        response = self.client.post(
            url,
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(date),
                "appointment_time": "10:00:00",
                "duration_minutes": 60,
                "status": "pending",
                "appointment_type": "first_visit",
                "clinic_location": "Unidade Centro - Av. Principal, 123",
                "notes": "check",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(Appointment.objects.exists())
        appointment = Appointment.objects.first()
        self.assertEqual(appointment.clinic_location, "Unidade Centro - Av. Principal, 123")
        assignment = DoctorPatientAssignment.objects.filter(patient=self.patient).first()
        self.assertIsNotNone(assignment)
        self.assertEqual(assignment.doctor_id, self.surgeon.id)

        notification = Notification.objects.filter(
            recipient=self.master,
            related_object_id=appointment.id,
        ).first()
        self.assertIsNotNone(notification)
        self.assertEqual(notification.title, "Novo agendamento criado")

    @patch("apps.appointments.views.dispatch_appointment_created_workflows_task.delay")
    def test_create_appointment_dispatches_confirmation_push(self, confirmation_delay_mock):
        self.client.force_authenticate(self.master)
        url = reverse("appointments-list")
        date = timezone.localdate() + timedelta(days=2)

        response = self.client.post(
            url,
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(date),
                "appointment_time": "11:00:00",
                "duration_minutes": 60,
                "status": "pending",
                "appointment_type": "first_visit",
                "clinic_location": "Unidade Centro - Av. Principal, 123",
                "notes": "novo agendamento",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        confirmation_delay_mock.assert_called_once_with(response.data["id"])

    def test_create_appointment_returns_409_when_slot_conflicts(self):
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=timezone.localtime().time().replace(hour=10, minute=0, second=0, microsecond=0),
            duration_minutes=60,
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        url = reverse("appointments-list")
        response = self.client.post(
            url,
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(timezone.localdate() + timedelta(days=1)),
                "appointment_time": "10:00:00",
                "duration_minutes": 60,
                "status": "pending",
                "appointment_type": "first_visit",
                "notes": "conflict test",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)
        self.assertIn("detail", response.data)

    def test_create_appointment_ignores_completed_slot_for_conflict(self):
        target_date = timezone.localdate() + timedelta(days=1)
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=target_date,
            appointment_time=timezone.localtime().time().replace(hour=10, minute=0, second=0, microsecond=0),
            duration_minutes=60,
            status=Appointment.StatusChoices.COMPLETED,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        response = self.client.post(
            reverse("appointments-list"),
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(target_date),
                "appointment_time": "10:00:00",
                "duration_minutes": 60,
                "status": "pending",
                "appointment_type": "first_visit",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_create_appointment_ignores_rescheduled_slot_for_conflict(self):
        target_date = timezone.localdate() + timedelta(days=1)
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=target_date,
            appointment_time=timezone.localtime().time().replace(hour=11, minute=0, second=0, microsecond=0),
            duration_minutes=60,
            status=Appointment.StatusChoices.RESCHEDULED,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        response = self.client.post(
            reverse("appointments-list"),
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(target_date),
                "appointment_time": "11:00:00",
                "duration_minutes": 60,
                "status": "pending",
                "appointment_type": "first_visit",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_patient_cannot_update_status(self):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=timezone.localtime().time().replace(hour=11, minute=0, second=0, microsecond=0),
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )

        self.client.force_authenticate(self.patient)
        url = reverse("appointments-update-status", kwargs={"pk": appointment.id})
        response = self.client.put(url, {"status": "confirmed"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    @patch("apps.appointments.views.create_postop_schedule")
    @patch("apps.appointments.views.schedule_appointment_reminder_workflows_task.delay")
    @patch("apps.appointments.views.dispatch_appointment_created_workflows_task.delay")
    def test_confirmed_surgery_only_dispatches_reminder(
        self,
        confirmation_delay_mock,
        reminder_delay,
        create_postop_schedule_mock,
    ):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=timezone.localtime().time().replace(hour=15, minute=0, second=0, microsecond=0),
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        url = reverse("appointments-update-status", kwargs={"pk": appointment.id})
        response = self.client.put(url, {"status": "confirmed"}, format="json")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        confirmation_delay_mock.assert_called_once_with(str(appointment.id))
        reminder_delay.assert_called_once_with(str(appointment.id))
        create_postop_schedule_mock.assert_not_called()

    @patch("apps.appointments.views.create_postop_schedule")
    @patch("apps.appointments.views.schedule_appointment_reminder_workflows_task.delay")
    def test_completed_surgery_dispatches_postop_creation(
        self,
        reminder_delay,
        create_postop_schedule_mock,
    ):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate(),
            appointment_time=timezone.localtime().time().replace(hour=16, minute=0, second=0, microsecond=0),
            status=Appointment.StatusChoices.IN_PROGRESS,
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        url = reverse("appointments-update-status", kwargs={"pk": appointment.id})
        response = self.client.put(url, {"status": "completed"}, format="json")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        create_postop_schedule_mock.assert_called_once_with(str(appointment.id))
        reminder_delay.assert_not_called()

    @patch("apps.appointments.views.create_postop_schedule")
    @patch("apps.appointments.views.schedule_appointment_reminder_workflows_task.delay")
    def test_pending_surgery_can_be_marked_completed_from_quick_action(
        self,
        reminder_delay,
        create_postop_schedule_mock,
    ):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate(),
            appointment_time=timezone.localtime().time().replace(hour=17, minute=30, second=0, microsecond=0),
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        url = reverse("appointments-update-status", kwargs={"pk": appointment.id})
        response = self.client.put(url, {"status": "completed"}, format="json")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        appointment.refresh_from_db()
        self.assertEqual(appointment.status, Appointment.StatusChoices.COMPLETED)
        create_postop_schedule_mock.assert_called_once_with(str(appointment.id))
        reminder_delay.assert_not_called()

    @patch("apps.appointments.views.create_postop_schedule")
    def test_update_status_rejects_completed_for_future_surgery_date(
        self,
        create_postop_schedule_mock,
    ):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=timezone.localtime().time().replace(hour=17, minute=45, second=0, microsecond=0),
            status=Appointment.StatusChoices.IN_PROGRESS,
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        url = reverse("appointments-update-status", kwargs={"pk": appointment.id})
        response = self.client.put(url, {"status": "completed"}, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("status", response.data)
        appointment.refresh_from_db()
        self.assertEqual(appointment.status, Appointment.StatusChoices.IN_PROGRESS)
        create_postop_schedule_mock.assert_not_called()

    @patch("apps.appointments.views.create_postop_schedule")
    def test_patch_update_to_completed_also_dispatches_postop_creation(
        self,
        create_postop_schedule_mock,
    ):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate(),
            appointment_time=timezone.localtime().time().replace(hour=17, minute=0, second=0, microsecond=0),
            status=Appointment.StatusChoices.IN_PROGRESS,
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        url = reverse("appointments-detail", kwargs={"pk": appointment.id})
        response = self.client.patch(
            url,
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(appointment.appointment_date),
                "appointment_time": "17:00:00",
                "duration_minutes": 60,
                "status": "completed",
                "appointment_type": "surgery",
                "notes": "cirurgia realizada",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        create_postop_schedule_mock.assert_called_once_with(str(appointment.id))

    @patch("apps.appointments.views.create_postop_schedule")
    def test_patch_update_rejects_completed_for_future_surgery_date(
        self,
        create_postop_schedule_mock,
    ):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=2),
            appointment_time=timezone.localtime().time().replace(hour=18, minute=0, second=0, microsecond=0),
            status=Appointment.StatusChoices.IN_PROGRESS,
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        url = reverse("appointments-detail", kwargs={"pk": appointment.id})
        response = self.client.patch(
            url,
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(appointment.appointment_date),
                "appointment_time": "18:00:00",
                "duration_minutes": 60,
                "status": "completed",
                "appointment_type": "surgery",
                "notes": "tentativa antecipada",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("status", response.data)
        appointment.refresh_from_db()
        self.assertEqual(appointment.status, Appointment.StatusChoices.IN_PROGRESS)
        create_postop_schedule_mock.assert_not_called()

    def test_patch_update_to_completed_creates_postop_journey(self):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate(),
            appointment_time=timezone.localtime().time().replace(hour=18, minute=0, second=0, microsecond=0),
            status=Appointment.StatusChoices.IN_PROGRESS,
            appointment_type=Appointment.AppointmentTypeChoices.SURGERY,
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        url = reverse("appointments-detail", kwargs={"pk": appointment.id})
        response = self.client.patch(
            url,
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(appointment.appointment_date),
                "appointment_time": "18:00:00",
                "duration_minutes": 60,
                "status": "completed",
                "appointment_type": "surgery",
                "notes": "cirurgia realizada",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(
            PostOpJourney.objects.filter(
                appointment_id=appointment.id,
                patient_id=self.patient.id,
            ).exists()
        )

    def test_available_professionals_for_patient_without_assignment(self):
        self.client.force_authenticate(self.patient)
        url = reverse("appointments-available-professionals")
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 2)

    def test_available_professionals_for_patient_with_assignment(self):
        DoctorPatientAssignment.objects.create(
            patient=self.patient,
            doctor=self.surgeon_2,
        )
        self.client.force_authenticate(self.patient)
        url = reverse("appointments-available-professionals")
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 1)
        self.assertEqual(response.data["results"][0]["id"], str(self.surgeon_2.id))
        self.assertTrue(response.data["results"][0]["is_assigned"])

    def test_available_slots_ignores_invalid_specialty_id(self):
        self.client.force_authenticate(self.patient)
        url = reverse("appointments-available-slots")
        date = timezone.localdate() + timedelta(days=1)
        response = self.client.get(
            url,
            {
                "professional_id": str(self.surgeon.id),
                "date": str(date),
                "specialty_id": "rinoplastia",
            },
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("slots", response.data)

    def test_available_slots_falls_back_to_default_weekday_schedule(self):
        self.client.force_authenticate(self.patient)
        url = reverse("appointments-available-slots")
        date = self._next_weekday_date(1)  # Tuesday

        response = self.client.get(
            url,
            {
                "professional_id": str(self.surgeon.id),
                "date": str(date),
            },
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["slots"])

    def test_available_slots_does_not_use_default_when_custom_availability_exists(self):
        ProfessionalAvailability.objects.create(
            professional=self.surgeon,
            day_of_week=0,  # Monday
            start_time=time(14, 0),
            end_time=time(16, 0),
            is_active=True,
        )

        self.client.force_authenticate(self.patient)
        url = reverse("appointments-available-slots")
        date = self._next_weekday_date(1)  # Tuesday has no custom availability

        response = self.client.get(
            url,
            {
                "professional_id": str(self.surgeon.id),
                "date": str(date),
            },
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["slots"], [])

    def test_surgeon_my_patients_includes_patient_with_scheduled_appointment(self):
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=timezone.localtime().time().replace(hour=14, minute=0, second=0, microsecond=0),
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )
        self.client.force_authenticate(self.surgeon)
        response = self.client.get(reverse("patients-my-patients"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get("results", response.data)
        ids = {str(item["id"]) for item in results}
        self.assertIn(str(self.patient.id), ids)

    def test_surgeon_list_only_returns_own_appointments(self):
        own_appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=timezone.localtime().time().replace(hour=9, minute=0, second=0, microsecond=0),
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon_2,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=timezone.localtime().time().replace(hour=10, minute=0, second=0, microsecond=0),
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )

        self.client.force_authenticate(self.surgeon)
        response = self.client.get(reverse("appointments-list"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get("results", response.data)
        ids = {str(item["id"]) for item in results}
        self.assertIn(str(own_appointment.id), ids)
        self.assertEqual(len(ids), 1)

    def test_surgeon_cannot_create_appointment_for_another_surgeon(self):
        self.client.force_authenticate(self.surgeon)
        url = reverse("appointments-list")
        date = timezone.localdate() + timedelta(days=1)

        response = self.client.post(
            url,
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon_2.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(date),
                "appointment_time": "10:00:00",
                "duration_minutes": 60,
                "status": "pending",
                "appointment_type": "first_visit",
                "clinic_location": "Unidade Centro - Av. Principal, 123",
                "notes": "agendamento inválido",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("professional", response.data)

    def test_professional_id_alias_filters_appointments_for_master(self):
        own_appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=timezone.localtime().time().replace(hour=11, minute=0, second=0, microsecond=0),
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )
        Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon_2,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=timezone.localtime().time().replace(hour=12, minute=0, second=0, microsecond=0),
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        response = self.client.get(
            reverse("appointments-list"),
            {"professional_id": str(self.surgeon.id)},
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get("results", response.data)
        ids = {str(item["id"]) for item in results}
        self.assertIn(str(own_appointment.id), ids)
        self.assertEqual(len(ids), 1)

    def test_update_appointment_returns_409_when_slot_conflicts(self):
        first = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=2),
            appointment_time=timezone.localtime().time().replace(hour=10, minute=0, second=0, microsecond=0),
            duration_minutes=60,
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            clinic_location="Sala 1",
            created_by=self.master,
        )
        second = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=2),
            appointment_time=timezone.localtime().time().replace(hour=12, minute=0, second=0, microsecond=0),
            duration_minutes=60,
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            clinic_location="Sala 1",
            created_by=self.master,
        )

        self.client.force_authenticate(self.patient)
        url = reverse("appointments-detail", kwargs={"pk": second.id})
        response = self.client.patch(
            url,
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(first.appointment_date),
                "appointment_time": "10:00:00",
                "duration_minutes": 60,
                "appointment_type": "first_visit",
                "clinic_location": "Sala 1",
                "notes": "reagendar conflito",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)

    def test_reschedule_updates_same_appointment_without_creating_new_row(self):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=3),
            appointment_time=timezone.localtime().time().replace(hour=10, minute=0, second=0, microsecond=0),
            duration_minutes=60,
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            clinic_location="Sala 1",
            notes="antes",
            created_by=self.master,
        )

        self.client.force_authenticate(self.patient)
        url = reverse("appointments-detail", kwargs={"pk": appointment.id})
        new_date = timezone.localdate() + timedelta(days=5)
        response = self.client.patch(
            url,
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(new_date),
                "appointment_time": "15:00:00",
                "duration_minutes": 60,
                "appointment_type": "first_visit",
                "clinic_location": "Sala 2",
                "notes": "depois",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(Appointment.objects.count(), 1)

        appointment.refresh_from_db()
        self.assertEqual(appointment.appointment_date, new_date)
        self.assertEqual(str(appointment.appointment_time), "15:00:00")
        self.assertEqual(appointment.clinic_location, "Sala 2")
        self.assertEqual(appointment.notes, "depois")

        notification = Notification.objects.filter(
            recipient=self.master,
            related_object_id=appointment.id,
            title="Agendamento remarcado",
        ).first()
        self.assertIsNotNone(notification)

    def test_master_reschedule_creates_admin_notification(self):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=2),
            appointment_time=timezone.localtime().time().replace(hour=9, minute=0, second=0, microsecond=0),
            duration_minutes=60,
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            clinic_location="Sala 1",
            created_by=self.master,
        )

        self.client.force_authenticate(self.master)
        response = self.client.patch(
            reverse("appointments-detail", kwargs={"pk": appointment.id}),
            {
                "patient": str(self.patient.id),
                "professional": str(self.surgeon.id),
                "specialty": str(self.specialty.id),
                "appointment_date": str(timezone.localdate() + timedelta(days=4)),
                "appointment_time": "14:00:00",
                "duration_minutes": 60,
                "status": "pending",
                "appointment_type": "first_visit",
                "clinic_location": "Sala 2",
                "notes": "reschedule master",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        notification = Notification.objects.filter(
            recipient=self.master,
            related_object_id=appointment.id,
            title="Agendamento remarcado",
        ).first()
        self.assertIsNotNone(notification)

    def test_available_slots_includes_current_slot_when_excluding_appointment_id(self):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=self._next_weekday_date(1),  # Tuesday
            appointment_time=time(10, 0),
            duration_minutes=60,
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )

        self.client.force_authenticate(self.patient)
        url = reverse("appointments-available-slots")

        no_exclude = self.client.get(
            url,
            {
                "professional_id": str(self.surgeon.id),
                "date": str(appointment.appointment_date),
            },
        )
        self.assertEqual(no_exclude.status_code, status.HTTP_200_OK)
        self.assertNotIn("10:00", no_exclude.data["slots"])

        with_exclude = self.client.get(
            url,
            {
                "professional_id": str(self.surgeon.id),
                "date": str(appointment.appointment_date),
                "appointment_id": str(appointment.id),
            },
        )
        self.assertEqual(with_exclude.status_code, status.HTTP_200_OK)
        self.assertIn("10:00", with_exclude.data["slots"])

    def test_patient_can_cancel_own_appointment_with_reason(self):
        appointment = Appointment.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            professional=self.surgeon,
            specialty=self.specialty,
            appointment_date=timezone.localdate() + timedelta(days=1),
            appointment_time=time(15, 0),
            duration_minutes=60,
            status=Appointment.StatusChoices.PENDING,
            appointment_type=Appointment.AppointmentTypeChoices.FIRST_VISIT,
            created_by=self.master,
        )

        self.client.force_authenticate(self.patient)
        response = self.client.delete(
            reverse("appointments-detail", kwargs={"pk": appointment.id}),
            {"reason": "Paciente solicitou o cancelamento"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        appointment.refresh_from_db()
        self.assertEqual(appointment.status, Appointment.StatusChoices.CANCELLED)
        self.assertEqual(
            appointment.cancellation_reason,
            "Paciente solicitou o cancelamento",
        )
