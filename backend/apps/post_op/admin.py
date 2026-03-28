from django.contrib import admin

from .models import EvolutionPhoto, PostOpChecklist, PostOpJourney, PostOpProtocol, UrgentMedicalRequest


@admin.register(PostOpProtocol)
class PostOpProtocolAdmin(admin.ModelAdmin):
    list_display = ("specialty", "day_number", "title", "is_milestone")
    list_filter = ("specialty", "is_milestone")


@admin.register(PostOpJourney)
class PostOpJourneyAdmin(admin.ModelAdmin):
    list_display = ("patient", "specialty", "surgery_date", "status")
    list_filter = ("status", "specialty")


@admin.register(PostOpChecklist)
class PostOpChecklistAdmin(admin.ModelAdmin):
    list_display = ("journey", "day_number", "item_text", "is_completed")
    list_filter = ("is_completed",)


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
