from django.contrib import admin

from .models import FlightInfo, HotelInfo, Transfer, TravelPlan


@admin.register(TravelPlan)
class TravelPlanAdmin(admin.ModelAdmin):
    list_display = ("id", "tenant", "patient", "passport_number", "created_at")
    search_fields = ("patient__email", "patient__first_name", "patient__last_name", "passport_number")
    list_filter = ("tenant", "created_at")


@admin.register(FlightInfo)
class FlightInfoAdmin(admin.ModelAdmin):
    list_display = ("id", "travel_plan", "direction", "flight_number", "flight_date", "flight_time")
    search_fields = ("flight_number", "airport", "airline")
    list_filter = ("direction", "flight_date")


@admin.register(HotelInfo)
class HotelInfoAdmin(admin.ModelAdmin):
    list_display = ("id", "travel_plan", "hotel_name", "checkin_date", "checkout_date")
    search_fields = ("hotel_name", "address", "room_number", "hotel_phone")


@admin.register(Transfer)
class TransferAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "travel_plan",
        "title",
        "transfer_date",
        "transfer_time",
        "status",
        "confirmed_by_patient",
        "display_order",
    )
    search_fields = ("title", "origin", "destination")
    list_filter = ("status", "transfer_date", "confirmed_by_patient")
