from __future__ import annotations

from django.core import mail
from django.test import override_settings
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.tenants.models import Tenant
from apps.users.models import GoKlinikUser


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
