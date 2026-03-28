from django.contrib import admin

from .models import Appointment, BlockedPeriod, ProfessionalAvailability


@admin.register(Appointment)
class AppointmentAdmin(admin.ModelAdmin):
    list_display = (
        "patient",
        "professional",
        "appointment_date",
        "appointment_time",
        "status",
        "appointment_type",
    )
    list_filter = ("tenant", "status", "appointment_type", "appointment_date")
    search_fields = (
        "patient__first_name",
        "patient__last_name",
        "patient__email",
        "professional__first_name",
        "professional__last_name",
    )


@admin.register(ProfessionalAvailability)
class ProfessionalAvailabilityAdmin(admin.ModelAdmin):
    list_display = ("professional", "day_of_week", "start_time", "end_time", "is_active")
    list_filter = ("day_of_week", "is_active")


@admin.register(BlockedPeriod)
class BlockedPeriodAdmin(admin.ModelAdmin):
    list_display = ("professional", "start_datetime", "end_datetime", "reason")
    list_filter = ("professional",)
