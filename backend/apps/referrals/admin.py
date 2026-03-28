from django.contrib import admin

from .models import Referral


@admin.register(Referral)
class ReferralAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "tenant",
        "referrer",
        "referred",
        "status",
        "commission_value",
        "created_at",
        "converted_at",
        "paid_at",
    )
    list_filter = ("status", "tenant")
    search_fields = (
        "referrer__email",
        "referred__email",
        "referrer__first_name",
        "referrer__last_name",
        "referred__first_name",
        "referred__last_name",
    )
    readonly_fields = ("created_at", "converted_at", "paid_at")
