from __future__ import annotations

from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.medical_records.models import MedicalDocument
from apps.patients.models import Patient
from apps.tenants.models import Tenant
from apps.users.models import GoKlinikUser


class MedicalRecordsViewsTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Med T1", slug="med-t1")
        self.master = GoKlinikUser.objects.create_user(
            email="master@med.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.patient = Patient.objects.create_user(
            email="patient@med.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="M",
            last_name="P",
        )

    def test_create_document_success(self):
        self.client.force_authenticate(self.master)
        url = reverse("medical-records-documents", kwargs={"patient_id": self.patient.id})
        response = self.client.post(
            url,
            {
                "document_type": "report",
                "title": "Lab result",
                "file_url": "https://example.com/report.pdf",
                "is_signed": False,
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(MedicalDocument.objects.count(), 1)

    def test_access_log_forbidden_for_patient(self):
        self.client.force_authenticate(self.patient)
        url = reverse("medical-records-access-log", kwargs={"patient_id": self.patient.id})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
