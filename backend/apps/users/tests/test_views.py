from __future__ import annotations

from datetime import datetime, timedelta
from io import BytesIO
from unittest.mock import patch

from django.core import mail
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.urls import reverse
from django.utils import timezone
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase

from apps.notifications.models import Notification
from apps.patients.models import Patient
from apps.tenants.models import Tenant
from apps.users.models import GoKlinikUser
from services.supabase_storage import SupabaseStorageUploadError


class AdminDashboardViewTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Dash T1", slug="dash-t1")
        self.master = GoKlinikUser.objects.create_user(
            email="master@dash.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.patient = GoKlinikUser.objects.create_user(
            email="patient@dash.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
        )

    def test_admin_dashboard_success(self):
        self.client.force_authenticate(self.master)
        response = self.client.get(reverse("api-admin-dashboard"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("faturamento_mes_atual", response.data)

    def test_admin_dashboard_forbidden_for_patient(self):
        self.client.force_authenticate(self.patient)
        response = self.client.get(reverse("api-admin-dashboard"))
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class TeamMemberDetailAPIViewTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Team Tenant", slug="team-tenant")
        self.master = GoKlinikUser.objects.create_user(
            email="master@team.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.surgeon = GoKlinikUser.objects.create_user(
            email="surgeon@team.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SURGEON,
        )

    def test_clinic_master_can_get_team_member_detail(self):
        self.client.force_authenticate(self.master)
        response = self.client.get(reverse("auth-team-detail", args=[self.surgeon.id]))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], str(self.surgeon.id))

    def test_clinic_master_can_update_team_member(self):
        self.client.force_authenticate(self.master)
        response = self.client.patch(
            reverse("auth-team-detail", args=[self.surgeon.id]),
            {
                "full_name": "Updated Surgeon",
                "phone": "+1 999 888",
                "is_visible_in_app": False,
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.surgeon.refresh_from_db()
        self.assertEqual(self.surgeon.full_name, "Updated Surgeon")
        self.assertEqual(self.surgeon.phone, "+1 999 888")
        self.assertFalse(self.surgeon.is_visible_in_app)

    def test_clinic_master_can_deactivate_team_member(self):
        self.client.force_authenticate(self.master)
        response = self.client.patch(
            reverse("auth-team-detail", args=[self.surgeon.id]),
            {"is_active": False},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.surgeon.refresh_from_db()
        self.assertFalse(self.surgeon.is_active)

    def test_cannot_deactivate_self(self):
        self.client.force_authenticate(self.master)
        response = self.client.patch(
            reverse("auth-team-detail", args=[self.master.id]),
            {"is_active": False},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_clinic_master_can_delete_team_member(self):
        self.client.force_authenticate(self.master)
        response = self.client.delete(reverse("auth-team-detail", args=[self.surgeon.id]))
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(GoKlinikUser.objects.filter(id=self.surgeon.id).exists())


@override_settings(
    RESEND_API_KEY="",
    EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend",
)
class InviteUserEmailLanguageTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Invite Tenant", slug="invite-tenant")
        self.master = GoKlinikUser.objects.create_user(
            email="master@invite.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )

    def test_invite_email_uses_language_from_payload(self):
        self.client.force_authenticate(self.master)
        response = self.client.post(
            reverse("auth-invite"),
            {
                "full_name": "Convite PT",
                "email": "invite-pt@invite.com",
                "role": "surgeon",
                "language": "pt",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn("Convite para entrar na Invite Tenant", mail.outbox[0].subject)
        self.assertIn("Você foi convidado(a) para entrar na Invite Tenant como Cirurgião.", mail.outbox[0].body)
        self.assertIn("Senha temporária:", mail.outbox[0].body)

    def test_invite_email_uses_accept_language_header_when_payload_language_is_missing(self):
        self.client.force_authenticate(self.master)
        response = self.client.post(
            reverse("auth-invite"),
            {
                "full_name": "Convite Header",
                "email": "invite-header@invite.com",
                "role": "surgeon",
            },
            format="json",
            HTTP_ACCEPT_LANGUAGE="pt-BR,pt;q=0.9,en;q=0.8",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn("Convite para entrar na Invite Tenant", mail.outbox[0].subject)


class RegisterPatientNotificationsTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Clinic Tenant", slug="clinic-tenant")
        self.master = GoKlinikUser.objects.create_user(
            email="owner@clinic.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )

    @patch("apps.users.serializers.supabase_sign_up", return_value=True)
    def test_register_patient_creates_notification_for_clinic_master(self, _supabase_signup_mock):
        response = self.client.post(
            reverse("auth-register"),
            {
                "full_name": "Paciente Novo",
                "clinic_id": str(self.tenant.id),
                "cpf": "12345678900",
                "email": "paciente.novo@clinic.com",
                "phone": "11999990000",
                "password": "12345678",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        notification = Notification.objects.filter(
            recipient=self.master,
            title="Novo paciente cadastrado",
        ).first()
        self.assertIsNotNone(notification)


class ImageAssetUploadAPIViewTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Upload Tenant", slug="upload-tenant")
        self.master = GoKlinikUser.objects.create_user(
            email="master@upload.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.patient = Patient.objects.create_user(
            email="patient@upload.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
        )
        self.upload_url = reverse("auth-assets-upload-image")

    @staticmethod
    def _png_file(name: str = "avatar.png") -> SimpleUploadedFile:
        buffer = BytesIO()
        Image.new("RGB", (2, 2), color=(12, 90, 190)).save(buffer, format="PNG")
        content = buffer.getvalue()
        return SimpleUploadedFile(name=name, content=content, content_type="image/png")

    @patch("apps.users.serializers.upload_file")
    def test_clinic_master_uploads_patient_image(self, upload_file_mock):
        upload_file_mock.return_value = "https://cdn.example.com/tenant/patient/avatar.png"
        self.client.force_authenticate(self.master)

        response = self.client.post(
            self.upload_url,
            {
                "target": "patient",
                "patient_id": str(self.patient.id),
                "file": self._png_file(),
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.patient.refresh_from_db()
        self.assertEqual(self.patient.avatar_url, upload_file_mock.return_value)
        self.assertEqual(response.data["image_url"], upload_file_mock.return_value)
        self.assertIn(f"{self.tenant.id}/patients/{self.patient.id}/", response.data["storage_path"])

    def test_patient_cannot_upload_clinic_image(self):
        self.client.force_authenticate(self.patient)
        response = self.client.post(
            self.upload_url,
            {
                "target": "clinic",
                "file": self._png_file(),
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    @patch("apps.users.serializers.upload_file")
    def test_returns_502_when_storage_provider_fails(self, upload_file_mock):
        upload_file_mock.side_effect = SupabaseStorageUploadError("storage down")
        self.client.force_authenticate(self.master)

        response = self.client.post(
            self.upload_url,
            {
                "target": "patient",
                "patient_id": str(self.patient.id),
                "file": self._png_file(),
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_502_BAD_GATEWAY)


class CurrentUserAvatarUploadAPIViewTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Avatar Tenant", slug="avatar-tenant")
        self.patient = Patient.objects.create_user(
            email="avatar@upload.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
        )
        self.upload_url = reverse("auth-me-avatar")

    @staticmethod
    def _image_file(
        name: str = "avatar.heic",
        *,
        content_type: str = "application/octet-stream",
    ) -> SimpleUploadedFile:
        buffer = BytesIO()
        Image.new("RGB", (2, 2), color=(12, 90, 190)).save(buffer, format="PNG")
        return SimpleUploadedFile(
            name=name,
            content=buffer.getvalue(),
            content_type=content_type,
        )

    @patch("apps.users.views.upload_file")
    def test_upload_accepts_octet_stream_when_extension_is_image(self, upload_file_mock):
        upload_file_mock.return_value = (
            "https://vjhdsqtrdfhmjqrajbty.supabase.co/storage/v1/object/public/"
            "clinic-assets/fe90f211-a15a-4304-847a-dac25092ac97/patients/"
            "1df50cbc-eab4-4f12-ad6d-6e20f3d14f99/avatars/"
            "161ed0a562db4c2f93fbcbe2441f4f74.jpg"
        )
        self.client.force_authenticate(self.patient)

        response = self.client.post(
            self.upload_url,
            {"avatar": self._image_file()},
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.patient.refresh_from_db()
        self.assertEqual(self.patient.avatar_url, upload_file_mock.return_value)

    @patch("apps.users.views.delete_file")
    @patch("apps.patients.models.Patient.save", side_effect=Exception("db failure"))
    @patch("apps.users.views.upload_file")
    def test_upload_removes_uploaded_file_when_db_persist_fails(
        self,
        upload_file_mock,
        _save_mock,
        delete_file_mock,
    ):
        uploaded_url = (
            "https://vjhdsqtrdfhmjqrajbty.supabase.co/storage/v1/object/public/clinic-assets/"
            "fe90f211-a15a-4304-847a-dac25092ac97/patients/1df50cbc-eab4-4f12-ad6d-6e20f3d14f99/"
            "avatars/29fd834e1627430d8580a0f5daddb60d.jpg"
        )
        upload_file_mock.return_value = uploaded_url
        self.client.force_authenticate(self.patient)

        response = self.client.post(
            self.upload_url,
            {"avatar": self._image_file(name="avatar.jpg", content_type="image/jpeg")},
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_502_BAD_GATEWAY)
        self.assertEqual(response.data["detail"], "Could not persist avatar after upload.")
        delete_file_mock.assert_called_once_with(uploaded_url)

    @patch("apps.users.views.upload_file")
    def test_upload_rejects_non_image_extension_with_octet_stream(self, upload_file_mock):
        self.client.force_authenticate(self.patient)

        response = self.client.post(
            self.upload_url,
            {"avatar": self._image_file(name="avatar.txt")},
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["detail"], "Invalid file type.")
        upload_file_mock.assert_not_called()


class PatientLoginTrackingTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Login Tenant", slug="login-tenant")
        self.patient = Patient.objects.create_user(
            email="patient@login.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Patient",
            last_name="Login",
        )
        self.clinic_master = GoKlinikUser.objects.create_user(
            email="master@login.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
            first_name="Master",
            last_name="Login",
        )

    @patch("apps.users.serializers.supabase_sign_in", return_value=True)
    @patch("apps.users.views.timezone.now")
    def test_patient_login_sets_install_date_and_updates_last_login(
        self,
        timezone_now_mock,
        _supabase_sign_in_mock,
    ):
        first_login = timezone.make_aware(datetime(2026, 1, 10, 10, 0, 0))
        second_login = first_login + timedelta(hours=2)
        timezone_now_mock.side_effect = [first_login, second_login]

        first_response = self.client.post(
            reverse("auth-login"),
            {"email": self.patient.email, "password": "pass12345"},
            format="json",
        )
        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.patient.refresh_from_db()
        self.assertEqual(self.patient.app_installed_at, first_login)
        self.assertEqual(self.patient.last_app_login_at, first_login)

        second_response = self.client.post(
            reverse("auth-login"),
            {"email": self.patient.email, "password": "pass12345"},
            format="json",
        )
        self.assertEqual(second_response.status_code, status.HTTP_200_OK)
        self.patient.refresh_from_db()
        self.assertEqual(self.patient.app_installed_at, first_login)
        self.assertEqual(self.patient.last_app_login_at, second_login)

    @patch("apps.users.serializers.supabase_sign_in", return_value=True)
    def test_non_patient_login_does_not_populate_app_tracking_fields(self, _supabase_sign_in_mock):
        response = self.client.post(
            reverse("auth-login"),
            {"email": self.clinic_master.email, "password": "pass12345"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.clinic_master.refresh_from_db()
        self.assertIsNone(self.clinic_master.app_installed_at)
        self.assertIsNone(self.clinic_master.last_app_login_at)


class ChangePasswordAPIViewTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Password Tenant", slug="password-tenant")
        self.patient = Patient.objects.create_user(
            email="password.patient@clinic.com",
            password="SenhaAtual123!",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            temp_password="Ab1!cdef",
        )
        self.url = reverse("auth-change-password")

    def test_change_password_success_clears_temp_password(self):
        self.client.force_authenticate(self.patient)

        response = self.client.post(
            self.url,
            {
                "current_password": "SenhaAtual123!",
                "new_password": "NovaSenha456!",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["detail"], "Senha alterada com sucesso")

        self.patient.refresh_from_db()
        self.assertTrue(self.patient.check_password("NovaSenha456!"))
        self.assertIsNone(self.patient.temp_password)

    def test_change_password_returns_400_when_current_password_is_invalid(self):
        self.client.force_authenticate(self.patient)

        response = self.client.post(
            self.url,
            {
                "current_password": "SenhaErrada123!",
                "new_password": "NovaSenha456!",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["detail"], "Senha atual incorreta")

        self.patient.refresh_from_db()
        self.assertTrue(self.patient.check_password("SenhaAtual123!"))
        self.assertEqual(self.patient.temp_password, "Ab1!cdef")
