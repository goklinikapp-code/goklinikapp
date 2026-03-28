from __future__ import annotations

from datetime import timedelta

from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from apps.financial.models import Transaction
from apps.patients.models import Patient
from apps.tenants.models import Tenant
from apps.users.models import GoKlinikUser


class FinancialViewsTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Fin T1", slug="fin-t1")
        self.master = GoKlinikUser.objects.create_user(
            email="master@fin.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.patient = Patient.objects.create_user(
            email="patient@fin.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="F",
            last_name="P",
        )

        self.transaction = Transaction.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            description="Procedure",
            amount="1000.00",
            transaction_type=Transaction.TransactionTypeChoices.PROCEDURE,
            status=Transaction.StatusChoices.PENDING,
            due_date=timezone.localdate() + timedelta(days=5),
            payment_method=Transaction.PaymentMethodChoices.CREDIT_CARD,
        )

    def test_my_transactions_success(self):
        self.client.force_authenticate(self.patient)
        response = self.client.get(reverse("financial-my-transactions"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["transactions"]), 1)

    def test_admin_transactions_forbidden_for_patient(self):
        self.client.force_authenticate(self.patient)
        response = self.client.get(reverse("financial-admin-transactions"))
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
