from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import GoKlinikUser, SaaSAISettings, UploadedImageAsset


@admin.register(GoKlinikUser)
class GoKlinikUserAdmin(UserAdmin):
    model = GoKlinikUser

    list_display = (
        "email",
        "role",
        "tenant",
        "is_active",
        "is_staff",
        "is_superuser",
    )
    list_filter = ("role", "tenant", "is_active", "is_staff")
    search_fields = ("email", "first_name", "last_name", "cpf")
    ordering = ("email",)

    fieldsets = (
        (None, {"fields": ("email", "password")}),
        (
            "Personal info",
            {
                "fields": (
                    "first_name",
                    "last_name",
                    "phone",
                    "cpf",
                    "date_of_birth",
                    "avatar_url",
                    "bio",
                    "crm_number",
                    "years_experience",
                    "is_visible_in_app",
                )
            },
        ),
        ("Tenant & Role", {"fields": ("tenant", "role")}),
        (
            "Permissions",
            {
                "fields": (
                    "is_active",
                    "is_staff",
                    "is_superuser",
                    "groups",
                    "user_permissions",
                )
            },
        ),
        ("Important dates", {"fields": ("last_login", "date_joined")}),
    )

    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": (
                    "email",
                    "password1",
                    "password2",
                    "tenant",
                    "role",
                    "is_active",
                    "is_staff",
                    "is_superuser",
                ),
            },
        ),
    )


@admin.register(SaaSAISettings)
class SaaSAISettingsAdmin(admin.ModelAdmin):
    list_display = ("provider", "model_name", "is_active", "updated_at")
    readonly_fields = ("created_at", "updated_at")


@admin.register(UploadedImageAsset)
class UploadedImageAssetAdmin(admin.ModelAdmin):
    list_display = ("target", "tenant", "patient", "uploaded_by", "created_at")
    list_filter = ("target", "tenant")
    search_fields = ("image_url", "storage_path", "patient__email", "uploaded_by__email")
    readonly_fields = ("id", "created_at")
