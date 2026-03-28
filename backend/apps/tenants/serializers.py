from rest_framework import serializers

from .models import Tenant, TenantSpecialty


class TenantBrandingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tenant
        fields = (
            "id",
            "name",
            "slug",
            "primary_color",
            "secondary_color",
            "accent_color",
            "logo_url",
            "favicon_url",
            "clinic_addresses",
            "ai_assistant_prompt",
        )
        read_only_fields = fields


class PublicTenantClinicSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tenant
        fields = ("id", "name", "slug")
        read_only_fields = fields


class TenantBrandingUpdateSerializer(serializers.ModelSerializer):
    clinic_addresses = serializers.ListField(
        child=serializers.CharField(max_length=255),
        required=False,
    )

    class Meta:
        model = Tenant
        fields = (
            "name",
            "primary_color",
            "secondary_color",
            "accent_color",
            "logo_url",
            "favicon_url",
            "clinic_addresses",
            "ai_assistant_prompt",
        )

    def validate_clinic_addresses(self, value):
        sanitized = []
        for item in value:
            text = (item or "").strip()
            if not text:
                continue
            sanitized.append(text[:255])
        return sanitized


class TenantSpecialtySerializer(serializers.ModelSerializer):
    class Meta:
        model = TenantSpecialty
        fields = (
            "id",
            "specialty_name",
            "description",
            "specialty_icon",
            "default_duration_minutes",
            "is_active",
            "display_order",
        )
        read_only_fields = ("id",)


class TenantSpecialtyWriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = TenantSpecialty
        fields = (
            "specialty_name",
            "description",
            "specialty_icon",
            "default_duration_minutes",
            "is_active",
            "display_order",
        )

    def validate_specialty_name(self, value):
        cleaned = (value or "").strip()
        if len(cleaned) < 2:
            raise serializers.ValidationError("Informe um nome válido para o procedimento.")
        tenant = self.context.get("tenant")
        queryset = TenantSpecialty.objects.filter(
            tenant=tenant,
            specialty_name__iexact=cleaned,
        )
        if self.instance:
            queryset = queryset.exclude(id=self.instance.id)
        if queryset.exists():
            raise serializers.ValidationError("Já existe um procedimento com esse nome.")
        return cleaned

    def validate_description(self, value):
        return (value or "").strip()
