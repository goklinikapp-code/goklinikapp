from __future__ import annotations

from datetime import date, time

from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.tenants.models import Tenant
from apps.travel_plans.models import FlightInfo, HotelInfo, Transfer, TravelPlan
from apps.users.models import GoKlinikUser


class TravelPlanViewsTestCase(APITestCase):
    def setUp(self):
        self.tenant = Tenant.objects.create(name="Travel T1", slug="travel-t1")
        self.other_tenant = Tenant.objects.create(name="Travel T2", slug="travel-t2")

        self.master = GoKlinikUser.objects.create_user(
            email="master@travel.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        self.secretary = GoKlinikUser.objects.create_user(
            email="secretary@travel.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.SECRETARY,
        )
        self.patient = GoKlinikUser.objects.create_user(
            email="patient@travel.com",
            password="pass12345",
            tenant=self.tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Ana",
            last_name="Silva",
        )
        self.other_patient = GoKlinikUser.objects.create_user(
            email="other-patient@travel.com",
            password="pass12345",
            tenant=self.other_tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            first_name="Other",
            last_name="Patient",
        )

    def test_my_plan_returns_404_when_patient_has_no_plan(self):
        self.client.force_authenticate(self.patient)
        response = self.client.get(reverse("travel-plans-my-plan"))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(response.data["detail"], "No travel plan found.")

    def test_my_plan_returns_200_with_complete_structure(self):
        travel_plan = TravelPlan.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            created_by=self.master,
            passport_number="AB1234567",
        )
        FlightInfo.objects.create(
            travel_plan=travel_plan,
            direction=FlightInfo.DirectionChoices.ARRIVAL,
            flight_number="TK101",
            flight_date=date(2026, 3, 15),
            flight_time=time(9, 45),
            airport="Istanbul Airport",
            airline="Turkish Airlines",
        )
        FlightInfo.objects.create(
            travel_plan=travel_plan,
            direction=FlightInfo.DirectionChoices.DEPARTURE,
            flight_number="TK204",
            flight_date=date(2026, 3, 28),
            flight_time=time(20, 30),
            airport="Istanbul Airport",
        )
        HotelInfo.objects.create(
            travel_plan=travel_plan,
            hotel_name="Istanbul Care Hotel",
            address="Fatih, Istanbul",
            checkin_date=date(2026, 3, 15),
            checkin_time=time(13, 0),
            checkout_date=date(2026, 3, 28),
            checkout_time=time(11, 0),
            room_number="1204",
            hotel_phone="+90 123 456 789",
            location_link="https://maps.google.com/?q=istanbul+care+hotel",
            observations="Late check-in arranged",
        )
        Transfer.objects.create(
            travel_plan=travel_plan,
            title="Transfer Aeroporto Hotel",
            transfer_date=date(2026, 3, 15),
            transfer_time=time(12, 30),
            origin="Istanbul Airport",
            destination="Istanbul Care Hotel",
            status=Transfer.StatusChoices.CONFIRMED,
            display_order=1,
        )

        self.client.force_authenticate(self.patient)
        response = self.client.get(reverse("travel-plans-my-plan"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], str(travel_plan.id))
        self.assertIsNotNone(response.data["arrival_flight"])
        self.assertIsNotNone(response.data["departure_flight"])
        self.assertIsNotNone(response.data["hotel"])
        self.assertEqual(len(response.data["transfers"]), 1)
        self.assertEqual(response.data["transfers"][0]["title"], "Transfer Aeroporto Hotel")

    def test_staff_can_create_plan_for_patient_from_same_tenant(self):
        self.client.force_authenticate(self.secretary)
        response = self.client.post(
            reverse("travel-plans-list-create"),
            {"patient_id": str(self.patient.id)},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(TravelPlan.objects.count(), 1)

    def test_staff_cannot_create_plan_for_other_tenant_patient(self):
        self.client.force_authenticate(self.master)
        response = self.client.post(
            reverse("travel-plans-list-create"),
            {"patient_id": str(self.other_patient.id)},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("patient_id", response.data)

    def test_patient_can_confirm_transfer(self):
        travel_plan = TravelPlan.objects.create(
            tenant=self.tenant,
            patient=self.patient,
            created_by=self.master,
        )
        transfer = Transfer.objects.create(
            travel_plan=travel_plan,
            title="Transfer Hotel Clínica",
            transfer_date=date(2026, 3, 16),
            transfer_time=time(7, 45),
            origin="Hotel",
            destination="Clínica",
            status=Transfer.StatusChoices.CONFIRMED,
            display_order=1,
        )

        self.client.force_authenticate(self.patient)
        response = self.client.put(
            reverse("travel-plans-transfer-confirm", kwargs={"transfer_id": transfer.id}),
            {},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        transfer.refresh_from_db()
        self.assertTrue(transfer.confirmed_by_patient)
        self.assertIsNotNone(transfer.confirmed_at)
