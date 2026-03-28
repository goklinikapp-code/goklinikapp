from __future__ import annotations

from decimal import Decimal
from unittest.mock import patch

from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.patients.models import Patient
from apps.referrals.models import Referral
from apps.tenants.models import Tenant
from apps.users.models import GoKlinikUser


class ReferralsFlowTestCase(APITestCase):
    def setUp(self):
        self.other_tenant = Tenant.objects.create(name="Other Referral Tenant", slug="other-referral-tenant")
        self.tenant = Tenant.objects.create(name="Referral Tenant", slug="referral-tenant")
        self.master = GoKlinikUser.objects.create_user(
            email="master@referral.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.referrer = GoKlinikUser.objects.create_user(
            email="referrer@referral.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Referrer",
            last_name="Patient",
            cpf="12345678900",
        )
        self.referrer.refresh_from_db()
        if not self.referrer.referral_code:
            self.referrer.referral_code = "GKTEST01"
            self.referrer.save(update_fields=["referral_code"])

        self.referred = GoKlinikUser.objects.create_user(
            email="referred@referral.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Referred",
            last_name="Patient",
            cpf="12345678901",
        )
        self.referral = Referral.objects.create(
            tenant=self.tenant,
            referrer=self.referrer,
            referred=self.referred,
            status=Referral.StatusChoices.PENDING,
        )

    @patch("apps.users.serializers.supabase_sign_up", return_value=True)
    def test_register_without_referral_code(self, _mock_supabase_signup):
        payload = {
            "full_name": "No Referral User",
            "cpf": "99999999999",
            "email": "noref@referral.com",
            "phone": "11999999999",
            "date_of_birth": "1990-01-01",
            "password": "pass12345",
        }
        response = self.client.post(
            reverse("auth-register"),
            payload,
            format="json",
            HTTP_X_TENANT_SLUG=self.tenant.slug,
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        created = GoKlinikUser.objects.get(email="noref@referral.com")
        self.assertIsNone(created.referred_by_id)
        self.assertTrue(created.referral_code)

    @patch("apps.users.serializers.supabase_sign_up", return_value=True)
    def test_register_with_valid_referral_code_creates_referral(self, _mock_supabase_signup):
        payload = {
            "full_name": "With Referral User",
            "cpf": "88888888888",
            "email": "withref@referral.com",
            "phone": "11988888888",
            "date_of_birth": "1991-01-01",
            "password": "pass12345",
            "referral_code": self.referrer.referral_code,
        }
        response = self.client.post(
            reverse("auth-register"),
            payload,
            format="json",
            HTTP_X_TENANT_SLUG=self.tenant.slug,
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        created = GoKlinikUser.objects.get(email="withref@referral.com")
        self.assertEqual(created.referred_by_id, self.referrer.id)
        created_referral = Referral.objects.filter(
            tenant=self.tenant,
            referrer=self.referrer,
            referred=created,
            status=Referral.StatusChoices.PENDING,
        ).first()
        self.assertIsNotNone(created_referral)
        self.assertTrue(created.referral_code)

    def test_patient_model_creation_generates_referral_code(self):
        patient = Patient.objects.create_user(
            email="patient-model@referral.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Patient",
            last_name="Model",
            cpf="12345678999",
        )
        patient.refresh_from_db()
        self.assertTrue(patient.referral_code)

    def test_my_referrals_returns_200_for_patient(self):
        self.client.force_authenticate(self.referrer)
        response = self.client.get(reverse("referrals-my-referrals"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("referral_code", response.data)
        self.assertEqual(
            response.data.get("referral_link"),
            f"https://goklinik.com/ref/{self.referrer.referral_code}",
        )
        self.assertIn("items", response.data)
        self.assertIn("total_commission_pending", response.data)
        self.assertIn("total_commission_paid", response.data)

    def test_my_referrals_returns_commission_totals(self):
        self.referral.status = Referral.StatusChoices.CONVERTED
        self.referral.commission_value = "55.50"
        self.referral.save(update_fields=["status", "commission_value"])
        Referral.objects.create(
            tenant=self.tenant,
            referrer=self.referrer,
            referred=GoKlinikUser.objects.create_user(
                email="paid@referral.com",
                password="pass12345",
                tenant=self.tenant,
                role=GoKlinikUser.RoleChoices.PATIENT,
                first_name="Paid",
                last_name="Patient",
                cpf="12345678001",
            ),
            status=Referral.StatusChoices.PAID,
            commission_value="100.00",
        )

        self.client.force_authenticate(self.referrer)
        response = self.client.get(reverse("referrals-my-referrals"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            Decimal(str(response.data.get("total_commission_pending"))),
            Decimal("55.50"),
        )
        self.assertEqual(
            Decimal(str(response.data.get("total_commission_paid"))),
            Decimal("100.00"),
        )

    def test_mark_converted_returns_200_for_clinic_master(self):
        self.client.force_authenticate(self.master)
        response = self.client.put(
            reverse("referrals-mark-converted", kwargs={"referral_id": self.referral.id}),
            {},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.referral.refresh_from_db()
        self.assertEqual(self.referral.status, Referral.StatusChoices.CONVERTED)
        self.assertIsNotNone(self.referral.converted_at)

    def test_mark_converted_returns_403_for_patient(self):
        self.client.force_authenticate(self.referrer)
        response = self.client.put(
            reverse("referrals-mark-converted", kwargs={"referral_id": self.referral.id}),
            {},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    @patch("apps.users.serializers.supabase_sign_up", return_value=True)
    def test_register_with_referral_code_without_tenant_header_uses_referrer_tenant(
        self, _mock_supabase_signup
    ):
        payload = {
            "full_name": "Referral Without Header",
            "cpf": "77777777777",
            "email": "without-header@referral.com",
            "phone": "11977777777",
            "date_of_birth": "1992-01-01",
            "password": "pass12345",
            "referral_code": self.referrer.referral_code,
        }
        response = self.client.post(reverse("auth-register"), payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        created = GoKlinikUser.objects.get(email="without-header@referral.com")
        self.assertEqual(created.tenant_id, self.tenant.id)
        self.assertEqual(created.referred_by_id, self.referrer.id)

    @patch("apps.users.serializers.supabase_sign_up", return_value=True)
    def test_register_with_full_referral_link_uses_code(self, _mock_supabase_signup):
        payload = {
            "full_name": "Referral Full Link",
            "cpf": "66555555555",
            "email": "full-link@referral.com",
            "phone": "11955555555",
            "date_of_birth": "1994-01-01",
            "password": "pass12345",
            "referral_code": f"https://goklinik.com/ref/{self.tenant.slug}/{self.referrer.referral_code}",
        }
        response = self.client.post(reverse("auth-register"), payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        created = GoKlinikUser.objects.get(email="full-link@referral.com")
        self.assertEqual(created.tenant_id, self.tenant.id)
        self.assertEqual(created.referred_by_id, self.referrer.id)

    @patch("apps.users.serializers.supabase_sign_up", return_value=True)
    def test_register_with_new_referral_link_pattern_uses_code(self, _mock_supabase_signup):
        payload = {
            "full_name": "Referral New Link Pattern",
            "cpf": "66554433221",
            "email": "new-link@referral.com",
            "phone": "11955554444",
            "date_of_birth": "1994-01-01",
            "password": "pass12345",
            "referral_code": f"https://goklinik.com/ref/{self.referrer.referral_code}",
        }
        response = self.client.post(reverse("auth-register"), payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        created = GoKlinikUser.objects.get(email="new-link@referral.com")
        self.assertEqual(created.tenant_id, self.tenant.id)
        self.assertEqual(created.referred_by_id, self.referrer.id)

    @patch("apps.users.serializers.supabase_sign_up", return_value=True)
    def test_register_with_referral_code_and_mismatched_tenant_header_returns_400(
        self, _mock_supabase_signup
    ):
        payload = {
            "full_name": "Referral Wrong Tenant Header",
            "cpf": "66666666666",
            "email": "wrong-tenant@referral.com",
            "phone": "11966666666",
            "date_of_birth": "1993-01-01",
            "password": "pass12345",
            "referral_code": self.referrer.referral_code,
        }
        response = self.client.post(
            reverse("auth-register"),
            payload,
            format="json",
            HTTP_X_TENANT_SLUG=self.other_tenant.slug,
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("referral_code", response.data)

    def test_admin_referral_link_returns_tenant_and_code(self):
        self.client.force_authenticate(self.master)
        response = self.client.get(reverse("referrals-admin-link"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.master.refresh_from_db()
        self.assertTrue(self.master.referral_code)
        self.assertEqual(response.data.get("tenant_slug"), self.tenant.slug)
        self.assertEqual(response.data.get("referral_code"), self.master.referral_code)
        self.assertEqual(
            response.data.get("referral_link"),
            f"https://goklinik.com/ref/{self.master.referral_code}",
        )
