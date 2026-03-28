from django.contrib import admin

from .models import Patient


@admin.register(Patient)
class PatientAdmin(admin.ModelAdmin):
    list_display = ("full_name", "email", "tenant", "status", "date_joined")
    search_fields = ("first_name", "last_name", "email", "cpf")
    list_filter = ("status", "tenant", "referral_source")
