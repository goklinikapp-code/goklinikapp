from django.contrib import admin

from .models import (
    EvolutionPhoto,
    PostOpChecklist,
    PostOperatoryCheckin,
    PostOpJourney,
    PostOpProtocol,
    UrgentMedicalRequest,
    UrgentTicket,
)


@admin.register(PostOpProtocol)
class PostOpProtocolAdmin(admin.ModelAdmin):
    list_display = ("specialty", "day_number", "title", "is_milestone")
    list_filter = ("specialty", "is_milestone")


@admin.register(PostOpJourney)
class PostOpJourneyAdmin(admin.ModelAdmin):
    list_display = (
        "patient",
        "clinic",
        "specialty",
        "surgery_date",
        "start_date",
        "end_date",
        "current_day",
        "status",
    )
    list_filter = ("status", "specialty")


@admin.register(PostOpChecklist)
class PostOpChecklistAdmin(admin.ModelAdmin):
    list_display = ("journey", "day_number", "item_text", "is_completed")
    list_filter = ("is_completed",)


@admin.register(PostOperatoryCheckin)
class PostOperatoryCheckinAdmin(admin.ModelAdmin):
    list_display = ("journey", "day", "pain_level", "has_fever", "created_at")
    list_filter = ("has_fever",)


@admin.register(EvolutionPhoto)
class EvolutionPhotoAdmin(admin.ModelAdmin):
    list_display = ("journey", "day_number", "uploaded_at", "is_visible_to_clinic")
    list_filter = ("is_visible_to_clinic", "is_anonymous")


@admin.register(UrgentMedicalRequest)
class UrgentMedicalRequestAdmin(admin.ModelAdmin):
    list_display = (
        "patient",
        "assigned_professional",
        "status",
        "created_at",
        "answered_at",
    )
    list_filter = ("status", "tenant")
    search_fields = ("patient__first_name", "patient__last_name", "patient__email")


@admin.register(UrgentTicket)
class UrgentTicketAdmin(admin.ModelAdmin):
    list_display = (
        "patient",
        "doctor",
        "status",
        "severity",
        "created_at",
    )
    list_filter = ("status", "severity", "clinic")
    search_fields = ("patient__first_name", "patient__last_name", "patient__email", "message")
