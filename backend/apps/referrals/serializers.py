from __future__ import annotations

from decimal import Decimal

from rest_framework import serializers

from .models import Lead, Referral
from apps.users.models import SaaSSeller


class ReferralItemSerializer(serializers.ModelSerializer):
    referred_name = serializers.CharField(source="referred.full_name", read_only=True)
    referred_email = serializers.EmailField(source="referred.email", read_only=True)

    class Meta:
        model = Referral
        fields = (
            "id",
            "referred_name",
            "referred_email",
            "status",
            "commission_value",
            "created_at",
            "converted_at",
        )


class AdminReferralListSerializer(serializers.ModelSerializer):
    referrer = serializers.SerializerMethodField()
    referred = serializers.SerializerMethodField()

    class Meta:
        model = Referral
        fields = (
            "id",
            "referrer",
            "referred",
            "status",
            "commission_value",
            "created_at",
            "converted_at",
            "paid_at",
        )

    def get_referrer(self, obj: Referral) -> dict[str, str]:
        return {
            "name": obj.referrer.full_name,
            "phone": obj.referrer.phone or "",
        }

    def get_referred(self, obj: Referral) -> dict[str, str]:
        return {
            "name": obj.referred.full_name,
            "phone": obj.referred.phone or "",
        }


class MarkPaidSerializer(serializers.Serializer):
    commission_value = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        min_value=Decimal("0.00"),
    )


class LeadSerializer(serializers.ModelSerializer):
    seller = serializers.SerializerMethodField(read_only=True)
    name = serializers.CharField(required=True, allow_blank=False, trim_whitespace=True)
    email = serializers.EmailField(required=True)
    phone = serializers.CharField(required=True, allow_blank=False, trim_whitespace=True)
    ref_code = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        trim_whitespace=True,
    )

    class Meta:
        model = Lead
        fields = ("id", "name", "email", "phone", "ref_code", "seller", "created_at")
        read_only_fields = ("id", "seller", "created_at")

    def validate_name(self, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("This field may not be blank.")
        return cleaned

    def validate_email(self, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("This field may not be blank.")
        return cleaned

    def validate_phone(self, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("This field may not be blank.")
        return cleaned

    def validate_ref_code(self, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned or None

    def create(self, validated_data):
        ref_code = validated_data.get("ref_code")
        seller = None
        if ref_code:
            seller = (
                SaaSSeller.objects.filter(
                    invite_code__iexact=ref_code,
                    is_active=True,
                )
                .only("id", "invite_code")
                .first()
            )
            if seller:
                validated_data["ref_code"] = seller.invite_code
        validated_data["seller"] = seller
        return super().create(validated_data)

    def get_seller(self, obj: Lead) -> dict[str, str] | None:
        if not obj.seller_id:
            return None
        return {
            "id": str(obj.seller_id),
            "name": obj.seller.full_name,
            "email": obj.seller.email,
            "ref_code": obj.seller.invite_code,
        }
