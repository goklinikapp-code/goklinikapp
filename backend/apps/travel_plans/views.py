from __future__ import annotations

from datetime import datetime

from django.db.models import Prefetch
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.users.models import GoKlinikUser

from .models import FlightInfo, Transfer, TravelPlan
from .serializers import (
    FlightInfoSerializer,
    HotelInfoSerializer,
    TransferConfirmSerializer,
    TransferSerializer,
    TravelPlanAdminPatientSerializer,
    TravelPlanCreateSerializer,
    TravelPlanSerializer,
    TravelPlanUpdateSerializer,
    mark_transfer_as_seen_by_patient,
)

STAFF_ALLOWED_ROLES = {
    GoKlinikUser.RoleChoices.CLINIC_MASTER,
    GoKlinikUser.RoleChoices.SECRETARY,
}


def _is_clinic_staff(user: GoKlinikUser) -> bool:
    return bool(user.tenant_id) and user.role in STAFF_ALLOWED_ROLES


def _is_patient(user: GoKlinikUser) -> bool:
    return bool(user.tenant_id) and user.role == GoKlinikUser.RoleChoices.PATIENT


def _travel_plan_queryset():
    return TravelPlan.objects.select_related(
        "tenant",
        "patient",
        "created_by",
        "hotel",
    ).prefetch_related(
        Prefetch(
            "flights",
            queryset=FlightInfo.objects.order_by("flight_date", "flight_time"),
        ),
        Prefetch(
            "transfers",
            queryset=Transfer.objects.order_by(
                "display_order",
                "transfer_date",
                "transfer_time",
            ),
        ),
    )


def _transfer_datetime(transfer: Transfer) -> datetime:
    naive_value = datetime.combine(transfer.transfer_date, transfer.transfer_time)
    if timezone.is_naive(naive_value):
        return timezone.make_aware(naive_value, timezone.get_current_timezone())
    return naive_value


class MyTravelPlanAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if not _is_patient(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        travel_plan = (
            _travel_plan_queryset()
            .filter(tenant_id=user.tenant_id, patient_id=user.id)
            .order_by("-updated_at")
            .first()
        )
        if not travel_plan:
            return Response(
                {"detail": "No travel plan found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(
            TravelPlanSerializer(travel_plan).data,
            status=status.HTTP_200_OK,
        )


class TravelPlanListCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        if not _is_clinic_staff(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = TravelPlanCreateSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)

        patient = serializer.context["patient"]
        travel_plan = TravelPlan.objects.create(
            tenant_id=user.tenant_id,
            patient=patient,
            created_by=user,
        )

        payload = (
            _travel_plan_queryset()
            .filter(id=travel_plan.id)
            .order_by("id")
            .first()
        )
        return Response(
            TravelPlanSerializer(payload or travel_plan).data,
            status=status.HTTP_201_CREATED,
        )


class TravelPlanDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, travel_plan_id):
        user = request.user
        if not _is_clinic_staff(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        travel_plan = get_object_or_404(
            _travel_plan_queryset(),
            id=travel_plan_id,
            tenant_id=user.tenant_id,
        )
        return Response(
            TravelPlanSerializer(travel_plan).data,
            status=status.HTTP_200_OK,
        )

    def put(self, request, travel_plan_id):
        user = request.user
        if not _is_clinic_staff(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        travel_plan = get_object_or_404(
            TravelPlan,
            id=travel_plan_id,
            tenant_id=user.tenant_id,
        )

        serializer = TravelPlanUpdateSerializer(
            travel_plan,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        payload = (
            _travel_plan_queryset()
            .filter(id=travel_plan.id)
            .order_by("id")
            .first()
        )
        return Response(
            TravelPlanSerializer(payload or travel_plan).data,
            status=status.HTTP_200_OK,
        )


class TravelPlanFlightUpsertAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, travel_plan_id):
        user = request.user
        if not _is_clinic_staff(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        travel_plan = get_object_or_404(
            TravelPlan,
            id=travel_plan_id,
            tenant_id=user.tenant_id,
        )

        serializer = FlightInfoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        flight, created = FlightInfo.objects.update_or_create(
            travel_plan=travel_plan,
            direction=data["direction"],
            defaults={
                "flight_number": data["flight_number"],
                "flight_date": data["flight_date"],
                "flight_time": data["flight_time"],
                "airport": data["airport"],
                "airline": data.get("airline", ""),
                "observations": data.get("observations", ""),
            },
        )

        return Response(
            FlightInfoSerializer(flight).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class TravelPlanHotelUpsertAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, travel_plan_id):
        user = request.user
        if not _is_clinic_staff(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        travel_plan = get_object_or_404(
            TravelPlan,
            id=travel_plan_id,
            tenant_id=user.tenant_id,
        )

        current = getattr(travel_plan, "hotel", None)
        serializer = HotelInfoSerializer(
            current,
            data=request.data,
            partial=current is not None,
        )
        serializer.is_valid(raise_exception=True)

        if current is None:
            hotel = serializer.save(travel_plan=travel_plan)
            response_status = status.HTTP_201_CREATED
        else:
            hotel = serializer.save()
            response_status = status.HTTP_200_OK

        return Response(
            HotelInfoSerializer(hotel).data,
            status=response_status,
        )


class TravelPlanTransferCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, travel_plan_id):
        user = request.user
        if not _is_clinic_staff(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        travel_plan = get_object_or_404(
            TravelPlan,
            id=travel_plan_id,
            tenant_id=user.tenant_id,
        )

        serializer = TransferSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        transfer = serializer.save(travel_plan=travel_plan)

        return Response(
            TransferSerializer(transfer).data,
            status=status.HTTP_201_CREATED,
        )


class TravelPlanTransferDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, transfer_id):
        user = request.user
        if not _is_clinic_staff(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        transfer = get_object_or_404(
            Transfer,
            id=transfer_id,
            travel_plan__tenant_id=user.tenant_id,
        )

        previous_status = transfer.status
        previous_date = transfer.transfer_date
        previous_time = transfer.transfer_time
        serializer = TransferSerializer(transfer, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        updated = serializer.save()
        if (
            previous_status != updated.status
            or previous_date != updated.transfer_date
            or previous_time != updated.transfer_time
        ) and updated.reminder_sent:
            updated.reminder_sent = False
            updated.save(update_fields=["reminder_sent"])

        return Response(
            TransferSerializer(updated).data,
            status=status.HTTP_200_OK,
        )

    def delete(self, request, transfer_id):
        user = request.user
        if not _is_clinic_staff(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        transfer = get_object_or_404(
            Transfer,
            id=transfer_id,
            travel_plan__tenant_id=user.tenant_id,
        )
        transfer.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class TravelPlanTransferConfirmAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, transfer_id):
        user = request.user
        if not _is_patient(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        transfer = get_object_or_404(
            Transfer,
            id=transfer_id,
            travel_plan__tenant_id=user.tenant_id,
            travel_plan__patient_id=user.id,
        )

        updated = mark_transfer_as_seen_by_patient(transfer)
        return Response(
            TransferConfirmSerializer(updated).data,
            status=status.HTTP_200_OK,
        )


class TravelPlanAdminPatientsAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if not _is_clinic_staff(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        patients = list(
            GoKlinikUser.objects.filter(
                tenant_id=user.tenant_id,
                role=GoKlinikUser.RoleChoices.PATIENT,
            )
            .order_by("first_name", "last_name", "email")
            .only("id", "first_name", "last_name", "email")
        )
        patient_ids = [row.id for row in patients]

        plans = list(
            _travel_plan_queryset().filter(
                tenant_id=user.tenant_id,
                patient_id__in=patient_ids,
            )
        )
        plan_by_patient_id = {str(plan.patient_id): plan for plan in plans}

        now = timezone.localtime()
        payload = []
        for patient in patients:
            plan = plan_by_patient_id.get(str(patient.id))
            arrival_date = None
            hotel_name = ""
            transfers_count = 0
            next_transfer_status = ""

            if plan is not None:
                arrival = next(
                    (
                        row
                        for row in plan.flights.all()
                        if row.direction == FlightInfo.DirectionChoices.ARRIVAL
                    ),
                    None,
                )
                if arrival is not None:
                    arrival_date = arrival.flight_date

                hotel = getattr(plan, "hotel", None)
                if hotel is not None:
                    hotel_name = hotel.hotel_name

                transfers = list(plan.transfers.all())
                transfers_count = len(transfers)

                if transfers:
                    upcoming = [
                        transfer
                        for transfer in transfers
                        if _transfer_datetime(transfer) >= now
                    ]
                    next_transfer = upcoming[0] if upcoming else transfers[0]
                    next_transfer_status = next_transfer.status

            payload.append(
                {
                    "patient_id": patient.id,
                    "patient_name": patient.full_name,
                    "travel_plan_id": plan.id if plan else None,
                    "arrival_date": arrival_date,
                    "hotel_name": hotel_name,
                    "transfers_count": transfers_count,
                    "next_transfer_status": next_transfer_status,
                }
            )

        serializer = TravelPlanAdminPatientSerializer(payload, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
