from __future__ import annotations

from django.utils import timezone
from rest_framework import serializers

from apps.users.models import GoKlinikUser

from .models import FlightInfo, HotelInfo, Transfer, TravelPlan


class FlightInfoSerializer(serializers.ModelSerializer):
    class Meta:
        model = FlightInfo
        fields = (
            "id",
            "travel_plan",
            "direction",
            "flight_number",
            "flight_date",
            "flight_time",
            "airport",
            "airline",
            "observations",
            "created_at",
        )
        read_only_fields = ("id", "travel_plan", "created_at")

    def validate_flight_number(self, value: str) -> str:
        cleaned = (value or "").strip()
        if not cleaned:
            raise serializers.ValidationError("Flight number is required.")
        return cleaned

    def validate_airport(self, value: str) -> str:
        cleaned = (value or "").strip()
        if not cleaned:
            raise serializers.ValidationError("Airport is required.")
        return cleaned

    def validate_airline(self, value: str) -> str:
        return (value or "").strip()

    def validate_observations(self, value: str) -> str:
        return (value or "").strip()


class HotelInfoSerializer(serializers.ModelSerializer):
    class Meta:
        model = HotelInfo
        fields = (
            "id",
            "travel_plan",
            "hotel_name",
            "address",
            "checkin_date",
            "checkin_time",
            "checkout_date",
            "checkout_time",
            "room_number",
            "hotel_phone",
            "location_link",
            "observations",
        )
        read_only_fields = ("id", "travel_plan")

    def validate_hotel_name(self, value: str) -> str:
        cleaned = (value or "").strip()
        if not cleaned:
            raise serializers.ValidationError("Hotel name is required.")
        return cleaned

    def validate_address(self, value: str) -> str:
        cleaned = (value or "").strip()
        if not cleaned:
            raise serializers.ValidationError("Address is required.")
        return cleaned

    def validate_room_number(self, value: str) -> str:
        return (value or "").strip()

    def validate_hotel_phone(self, value: str) -> str:
        return (value or "").strip()

    def validate_observations(self, value: str) -> str:
        return (value or "").strip()

    def validate(self, attrs):
        attrs = super().validate(attrs)
        instance = getattr(self, "instance", None)

        checkin_date = attrs.get("checkin_date", getattr(instance, "checkin_date", None))
        checkout_date = attrs.get("checkout_date", getattr(instance, "checkout_date", None))

        if checkin_date and checkout_date and checkout_date < checkin_date:
            raise serializers.ValidationError(
                {"checkout_date": "Checkout date must be equal to or after check-in date."}
            )

        checkin_time = attrs.get("checkin_time", getattr(instance, "checkin_time", None))
        checkout_time = attrs.get("checkout_time", getattr(instance, "checkout_time", None))
        if (
            checkin_date
            and checkout_date
            and checkin_time
            and checkout_time
            and checkout_date == checkin_date
            and checkout_time < checkin_time
        ):
            raise serializers.ValidationError(
                {"checkout_time": "Checkout time must be equal to or after check-in time."}
            )

        return attrs


class TransferSerializer(serializers.ModelSerializer):
    class Meta:
        model = Transfer
        fields = (
            "id",
            "travel_plan",
            "title",
            "transfer_date",
            "transfer_time",
            "origin",
            "destination",
            "observations",
            "status",
            "reminder_sent",
            "confirmed_by_patient",
            "confirmed_at",
            "display_order",
            "created_at",
        )
        read_only_fields = (
            "id",
            "travel_plan",
            "reminder_sent",
            "confirmed_by_patient",
            "confirmed_at",
            "created_at",
        )

    def validate_title(self, value: str) -> str:
        cleaned = (value or "").strip()
        if not cleaned:
            raise serializers.ValidationError("Title is required.")
        return cleaned

    def validate_origin(self, value: str) -> str:
        cleaned = (value or "").strip()
        if not cleaned:
            raise serializers.ValidationError("Origin is required.")
        return cleaned

    def validate_destination(self, value: str) -> str:
        cleaned = (value or "").strip()
        if not cleaned:
            raise serializers.ValidationError("Destination is required.")
        return cleaned

    def validate_observations(self, value: str) -> str:
        return (value or "").strip()

    def validate_display_order(self, value: int) -> int:
        if value < 0:
            raise serializers.ValidationError("Display order cannot be negative.")
        return value


class TravelPlanSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source="patient.full_name", read_only=True)
    arrival_flight = serializers.SerializerMethodField()
    departure_flight = serializers.SerializerMethodField()
    hotel = HotelInfoSerializer(read_only=True)
    transfers = TransferSerializer(many=True, read_only=True)

    class Meta:
        model = TravelPlan
        fields = (
            "id",
            "tenant",
            "patient",
            "patient_name",
            "passport_number",
            "created_by",
            "arrival_flight",
            "departure_flight",
            "hotel",
            "transfers",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "tenant",
            "patient",
            "created_by",
            "arrival_flight",
            "departure_flight",
            "hotel",
            "transfers",
            "created_at",
            "updated_at",
        )

    def _flight_by_direction(self, obj: TravelPlan, direction: str):
        flights = getattr(obj, "flights", None)
        if flights is not None and hasattr(flights, "all"):
            row = next((item for item in flights.all() if item.direction == direction), None)
        else:
            row = obj.flights.filter(direction=direction).first()

        if not row:
            return None

        return FlightInfoSerializer(row).data

    def get_arrival_flight(self, obj: TravelPlan):
        return self._flight_by_direction(obj, FlightInfo.DirectionChoices.ARRIVAL)

    def get_departure_flight(self, obj: TravelPlan):
        return self._flight_by_direction(obj, FlightInfo.DirectionChoices.DEPARTURE)


class TravelPlanCreateSerializer(serializers.Serializer):
    patient_id = serializers.UUIDField()

    def validate_patient_id(self, value):
        request = self.context["request"]
        user = request.user

        patient = (
            GoKlinikUser.objects.filter(
                id=value,
                tenant_id=user.tenant_id,
                role=GoKlinikUser.RoleChoices.PATIENT,
                is_active=True,
            )
            .order_by("id")
            .first()
        )
        if not patient:
            raise serializers.ValidationError("Patient not found for this tenant.")

        if TravelPlan.objects.filter(patient_id=patient.id).exists():
            raise serializers.ValidationError("This patient already has a travel plan.")

        self.context["patient"] = patient
        return value


class TravelPlanUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = TravelPlan
        fields = ("passport_number",)

    def validate_passport_number(self, value: str) -> str:
        return (value or "").strip()


class TransferConfirmSerializer(serializers.ModelSerializer):
    class Meta:
        model = Transfer
        fields = (
            "id",
            "title",
            "transfer_date",
            "transfer_time",
            "origin",
            "destination",
            "observations",
            "status",
            "confirmed_by_patient",
            "confirmed_at",
            "display_order",
        )
        read_only_fields = fields


class TravelPlanAdminPatientSerializer(serializers.Serializer):
    patient_id = serializers.UUIDField()
    patient_name = serializers.CharField()
    travel_plan_id = serializers.UUIDField(allow_null=True)
    arrival_date = serializers.DateField(allow_null=True)
    hotel_name = serializers.CharField(allow_blank=True)
    transfers_count = serializers.IntegerField()
    next_transfer_status = serializers.CharField(allow_blank=True)


class TransferStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Transfer.StatusChoices.choices)

    def apply(self, transfer: Transfer) -> Transfer:
        transfer.status = self.validated_data["status"]
        transfer.save(update_fields=["status"])
        return transfer


def mark_transfer_as_seen_by_patient(transfer: Transfer) -> Transfer:
    if transfer.confirmed_by_patient:
        return transfer

    transfer.confirmed_by_patient = True
    transfer.confirmed_at = timezone.now()
    transfer.save(update_fields=["confirmed_by_patient", "confirmed_at"])
    return transfer
