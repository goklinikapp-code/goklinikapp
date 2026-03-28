from django.contrib import admin

from .models import Tenant, TenantSpecialty


@admin.register(Tenant)
class TenantAdmin(admin.ModelAdmin):
    list_display = ("name", "slug", "plan", "is_active", "created_at")
    search_fields = ("name", "slug")
    list_filter = ("plan", "is_active")


@admin.register(TenantSpecialty)
class TenantSpecialtyAdmin(admin.ModelAdmin):
    list_display = ("specialty_name", "tenant", "is_active", "display_order")
    list_filter = ("is_active", "tenant")
    search_fields = ("specialty_name",)
