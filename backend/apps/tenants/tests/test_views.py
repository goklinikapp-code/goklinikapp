from __future__ import annotations

from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.patients.models import Patient
from apps.tenants.models import Tenant, TenantSpecialty
from apps.users.models import GoKlinikUser


class TenantProceduresViewTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Clinic A", slug="clinic-a")
        self.other_tenant = Tenant.objects.create(name="Clinic B", slug="clinic-b")

        self.patient = Patient.objects.create_user(
            email="patient@clinic-a.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Pat",
            last_name="One",
        )

        self.active_procedure = TenantSpecialty.objects.create(
            tenant=self.tenant,
            specialty_name="Rinoplastia",
            description="Correção estética e funcional do nariz.",
            is_active=True,
        )
        TenantSpecialty.objects.create(
            tenant=self.tenant,
            specialty_name="Lipo HD",
            description="Remodelação corporal avançada.",
            is_active=False,
        )
        TenantSpecialty.objects.create(
            tenant=self.other_tenant,
            specialty_name="Mamoplastia",
            description="Procedimento de redução mamária.",
            is_active=True,
        )

    def test_patient_can_list_only_active_procedures_from_own_tenant(self):
        self.client.force_authenticate(self.patient)

        response = self.client.get(reverse("tenant-procedures"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["id"], str(self.active_procedure.id))

    def test_patient_cannot_scope_procedures_to_another_tenant(self):
        self.client.force_authenticate(self.patient)

        response = self.client.get(
            reverse("tenant-procedures"),
            {"tenant_id": str(self.other_tenant.id)},
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["id"], str(self.active_procedure.id))

