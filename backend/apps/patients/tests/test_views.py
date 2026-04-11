from __future__ import annotations

import re
from datetime import timedelta
from io import BytesIO

from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse
from django.utils import timezone
from openpyxl import Workbook
from rest_framework import status
from rest_framework.test import APITestCase

from apps.appointments.models import Appointment
from apps.patients.models import DoctorPatientAssignment, Patient
from apps.pre_operatory.models import PreOperatory
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

    def test_surgeon_cannot_assign_doctor_to_patient(self):
        self.client.force_authenticate(self.surgeon_a)

        response = self.client.post(
            reverse("patients-assign-doctor", args=[self.patient_a.id]),
            {
                "doctor_id": str(self.surgeon_b.id),
                "notes": "Tentativa indevida de redirecionamento.",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

        assignment = DoctorPatientAssignment.objects.filter(
            patient=self.patient_a
        ).first()
        self.assertIsNotNone(assignment)
        self.assertEqual(str(assignment.doctor_id), str(self.surgeon_a.id))

    def test_my_patients_exposes_pre_operatory_selected_procedure_name(self):
        procedure = TenantSpecialty.objects.create(
            tenant=self.tenant,
            specialty_name="Lipo HD",
            description="Procedimento de contorno corporal.",
            is_active=True,
        )
        PreOperatory.objects.create(
            patient=self.patient_a,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.PENDING,
            height=1.70,
            weight=70,
            procedure=procedure,
        )

        self.client.force_authenticate(self.surgeon_a)
        response = self.client.get(reverse("patients-my-patients"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        row = response.data["results"][0]
        self.assertEqual(row["id"], str(self.patient_a.id))
        self.assertEqual(
            row["pre_operatory_procedure_name"],
            procedure.specialty_name,
        )

    def test_import_patients_csv_smoke_success(self):
        self.client.force_authenticate(self.master)
        csv_content = (
            "nome,email,telefone\n"
            "Ana Souza,ana.souza@patients.com,11911111111\n"
            "Bruno Lima,bruno.lima@patients.com,11922222222\n"
            "Carla Dias,carla.dias@patients.com,11933333333\n"
        )
        upload = SimpleUploadedFile(
            "pacientes.csv",
            csv_content.encode("utf-8"),
            content_type="text/csv",
        )

        response = self.client.post(
            reverse("patients-import-patients"),
            {"file": upload},
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["total_rows"], 3)
        self.assertEqual(response.data["imported"], 3)
        self.assertEqual(response.data["duplicates"], 0)
        self.assertEqual(response.data["errors"], 0)

    def test_import_patients_xlsx_smoke_success(self):
        self.client.force_authenticate(self.master)

        workbook = Workbook()
        worksheet = workbook.active
        worksheet.append(["nome", "email", "telefone"])
        worksheet.append(["Maria Excel", "maria.excel@patients.com", "11944444444"])
        worksheet.append(["Pedro Excel", "pedro.excel@patients.com", "11955555555"])

        stream = BytesIO()
        workbook.save(stream)
        stream.seek(0)
        upload = SimpleUploadedFile(
            "pacientes.xlsx",
            stream.read(),
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )

        response = self.client.post(
            reverse("patients-import-patients"),
            {"file": upload},
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["total_rows"], 2)
        self.assertEqual(response.data["imported"], 2)
        self.assertEqual(response.data["duplicates"], 0)
        self.assertEqual(response.data["errors"], 0)

    def test_import_patients_generates_temp_password_with_expected_pattern(self):
        self.client.force_authenticate(self.master)
        csv_content = (
            "nome,email,telefone\n"
            "Ana Temp,ana.temp@patients.com,11911111111\n"
            "Bruno Temp,bruno.temp@patients.com,11922222222\n"
        )
        upload = SimpleUploadedFile(
            "pacientes.csv",
            csv_content.encode("utf-8"),
            content_type="text/csv",
        )

        response = self.client.post(
            reverse("patients-import-patients"),
            {"file": upload},
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["imported"], 2)

        imported_users = Patient.objects.filter(
            email__in=["ana.temp@patients.com", "bruno.temp@patients.com"],
        ).order_by("email")
        self.assertEqual(imported_users.count(), 2)

        for imported_user in imported_users:
            self.assertIsNotNone(imported_user.temp_password)
            self.assertEqual(len(imported_user.temp_password), 8)
            self.assertRegex(imported_user.temp_password, r"[A-Z]")
            self.assertRegex(imported_user.temp_password, r"[0-9]")
            self.assertRegex(imported_user.temp_password, r"[!@#$%&]")
            self.assertRegex(imported_user.temp_password, r"^[A-Za-z0-9!@#$%&]{8}$")
            lowercase_count = len(re.findall(r"[a-z]", imported_user.temp_password))
            self.assertEqual(lowercase_count, 5)
            self.assertTrue(imported_user.check_password(imported_user.temp_password))

    def test_import_patients_csv_smoke_with_duplicate(self):
        self.client.force_authenticate(self.master)
        csv_content = (
            "nome,email,telefone\n"
            "Paciente A Duplicado,patient-a@patients.com,11911111111\n"
            "Bruno Lima,bruno.lima2@patients.com,11922222222\n"
            "Carla Dias,carla.dias2@patients.com,11933333333\n"
        )
        upload = SimpleUploadedFile(
            "pacientes.csv",
            csv_content.encode("utf-8"),
            content_type="text/csv",
        )

        response = self.client.post(
            reverse("patients-import-patients"),
            {"file": upload},
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["total_rows"], 3)
        self.assertEqual(response.data["imported"], 2)
        self.assertEqual(response.data["duplicates"], 1)
        self.assertEqual(response.data["errors"], 0)

    def test_filter_app_status_installed(self):
        now = timezone.now()
        self.patient_a.app_installed_at = now
        self.patient_a.last_app_login_at = now
        self.patient_a.save(update_fields=["app_installed_at", "last_app_login_at"])

        self.client.force_authenticate(self.master)
        response = self.client.get(reverse("patients-list"), {"app_status": "installed"})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item["id"] for item in response.data["results"]}
        self.assertEqual(ids, {str(self.patient_a.id)})
        self.assertIsNotNone(response.data["results"][0]["app_installed_at"])
        self.assertIsNotNone(response.data["results"][0]["last_app_login_at"])

    def test_filter_pre_op_approved_returns_only_patients_with_approved_record(self):
        PreOperatory.objects.create(
            patient=self.patient_a,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.APPROVED,
        )
        PreOperatory.objects.create(
            patient=self.patient_b,
            tenant=self.tenant,
            status=PreOperatory.StatusChoices.PENDING,
        )

        self.client.force_authenticate(self.master)
        response = self.client.get(reverse("patients-list"), {"pre_op_approved": "true"})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item["id"] for item in response.data["results"]}
        self.assertEqual(ids, {str(self.patient_a.id)})

    def test_import_patients_forbidden_for_surgeon(self):
        self.client.force_authenticate(self.surgeon_a)
        upload = SimpleUploadedFile(
            "pacientes.csv",
            "nome,email,telefone\nTeste,teste@patients.com,11911111111\n".encode("utf-8"),
            content_type="text/csv",
        )

        response = self.client.post(
            reverse("patients-import-patients"),
            {"file": upload},
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_patient_detail_exposes_temp_password_for_clinic_master(self):
        self.patient_a.temp_password = "Ab1!cdef"
        self.patient_a.save(update_fields=["temp_password"])
        self.client.force_authenticate(self.master)

        response = self.client.get(reverse("patients-detail", args=[self.patient_a.id]))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["temp_password"], "Ab1!cdef")

    def test_patient_detail_hides_temp_password_for_surgeon(self):
        self.patient_a.temp_password = "Ab1!cdef"
        self.patient_a.save(update_fields=["temp_password"])
        self.client.force_authenticate(self.surgeon_a)

        response = self.client.get(reverse("patients-detail", args=[self.patient_a.id]))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIsNone(response.data["temp_password"])

    def test_patient_detail_returns_assigned_doctor_when_assignment_exists(self):
        DoctorPatientAssignment.objects.update_or_create(
            patient=self.patient_a,
            defaults={
                "doctor": self.surgeon_a,
                "assigned_by": self.master,
            },
        )
        self.client.force_authenticate(self.master)

        response = self.client.get(reverse("patients-detail", args=[self.patient_a.id]))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIsNotNone(response.data["assigned_doctor"])
        self.assertEqual(
            response.data["assigned_doctor"]["id"],
            str(self.surgeon_a.id),
        )
