from __future__ import annotations

from decimal import Decimal

from rest_framework import serializers

from .models import Referral


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
