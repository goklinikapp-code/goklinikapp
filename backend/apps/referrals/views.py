from __future__ import annotations

from decimal import Decimal
from urllib.parse import urlparse

from django.conf import settings
from django.db.models import Sum
from django.db.models.functions import Coalesce
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.users.models import GoKlinikUser
from apps.users.signals import assign_referral_code_if_missing

from .models import Referral
from .serializers import AdminReferralListSerializer, MarkPaidSerializer, ReferralItemSerializer

REFERRAL_BASE_URL = settings.REFERRAL_BASE_URL


def build_referral_link(tenant_slug: str | None, referral_code: str | None) -> str:
    normalized_code = (referral_code or "").strip().upper()

    # Padrão oficial: /ref/{CODIGO}
    # Mantemos tenant_slug no contrato da função apenas por compatibilidade de chamada.
    if normalized_code:
        return f"{REFERRAL_BASE_URL}/{normalized_code}"
    return f"{REFERRAL_BASE_URL}/"


def normalize_referral_code(referral_code: str | None) -> str:
    if not referral_code:
        return ""

    normalized = referral_code.strip()
    if "://" in normalized:
        parsed = urlparse(normalized)
        path_chunks = [chunk for chunk in parsed.path.split("/") if chunk]
        normalized = path_chunks[-1] if path_chunks else ""
    elif "/" in normalized:
        path_chunks = [chunk for chunk in normalized.split("/") if chunk]
        normalized = path_chunks[-1] if path_chunks else normalized

    return normalized.strip().upper()


class PublicReferralLookupAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, codigo):
        normalized_code = normalize_referral_code(codigo)
        if not normalized_code:
            return Response(
                {"detail": "Código de indicação inválido."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        referrer = (
            GoKlinikUser.objects.select_related("tenant")
            .filter(
                referral_code=normalized_code,
                is_active=True,
                tenant__is_active=True,
            )
            .exclude(role=GoKlinikUser.RoleChoices.SUPER_ADMIN)
            .first()
        )
        if not referrer or not referrer.tenant_id or not referrer.tenant:
            return Response(
                {"detail": "Código de indicação inválido."},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(
            {
                "codigo": normalized_code,
                "clinica_id": str(referrer.tenant_id),
                "clinica_nome": referrer.tenant.name,
            },
            status=status.HTTP_200_OK,
        )


class MyReferralsAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        queryset = (
            Referral.objects.filter(tenant_id=user.tenant_id, referrer_id=user.id)
            .select_related("referred")
            .order_by("-created_at")
        )

        referral_code = assign_referral_code_if_missing(user) or user.referral_code or ""
        tenant_slug = user.tenant.slug if user.tenant_id and user.tenant else ""
        referral_link = build_referral_link(tenant_slug=tenant_slug, referral_code=referral_code)

        return Response(
            {
                "referral_code": referral_code,
                "referral_link": referral_link,
                "total_pending": queryset.filter(status=Referral.StatusChoices.PENDING).count(),
                "total_converted": queryset.filter(status=Referral.StatusChoices.CONVERTED).count(),
                "total_paid": queryset.filter(status=Referral.StatusChoices.PAID).count(),
                "total_commission_pending": queryset.filter(
                    status=Referral.StatusChoices.CONVERTED
                ).aggregate(total=Coalesce(Sum("commission_value"), Decimal("0.00")))[
                    "total"
                ],
                "total_commission_paid": queryset.filter(
                    status=Referral.StatusChoices.PAID
                ).aggregate(total=Coalesce(Sum("commission_value"), Decimal("0.00")))[
                    "total"
                ],
                "items": ReferralItemSerializer(queryset, many=True).data,
            },
            status=status.HTTP_200_OK,
        )


class AdminReferralsListAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)

        queryset = (
            Referral.objects.filter(tenant_id=user.tenant_id)
            .select_related("referrer", "referred")
            .order_by("-created_at")
        )
        status_filter = request.query_params.get("status")
        if status_filter:
            queryset = queryset.filter(status=status_filter)

        return Response(AdminReferralListSerializer(queryset, many=True).data, status=status.HTTP_200_OK)


class MarkReferralConvertedAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, referral_id):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)

        referral = (
            Referral.objects.filter(id=referral_id, tenant_id=user.tenant_id)
            .select_related("referrer", "referred")
            .first()
        )
        if not referral:
            return Response({"detail": "Referral not found."}, status=status.HTTP_404_NOT_FOUND)

        referral.status = Referral.StatusChoices.CONVERTED
        referral.converted_at = timezone.now()
        referral.save(update_fields=["status", "converted_at"])
        return Response(AdminReferralListSerializer(referral).data, status=status.HTTP_200_OK)


class MarkReferralPaidAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, referral_id):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)

        referral = (
            Referral.objects.filter(id=referral_id, tenant_id=user.tenant_id)
            .select_related("referrer", "referred")
            .first()
        )
        if not referral:
            return Response({"detail": "Referral not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = MarkPaidSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        now = timezone.now()
        referral.status = Referral.StatusChoices.PAID
        referral.commission_value = serializer.validated_data["commission_value"]
        referral.paid_at = now
        if not referral.converted_at:
            referral.converted_at = now
            referral.save(update_fields=["status", "commission_value", "paid_at", "converted_at"])
        else:
            referral.save(update_fields=["status", "commission_value", "paid_at"])

        return Response(AdminReferralListSerializer(referral).data, status=status.HTTP_200_OK)


class AdminReferralsSummaryAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)

        queryset = Referral.objects.filter(tenant_id=user.tenant_id)

        total_commission_pending = queryset.filter(status=Referral.StatusChoices.CONVERTED).aggregate(
            total=Coalesce(Sum("commission_value"), Decimal("0.00"))
        )["total"]
        total_commission_paid = queryset.filter(status=Referral.StatusChoices.PAID).aggregate(
            total=Coalesce(Sum("commission_value"), Decimal("0.00"))
        )["total"]

        return Response(
            {
                "total_referrals": queryset.count(),
                "total_converted": queryset.filter(status=Referral.StatusChoices.CONVERTED).count(),
                "total_paid_count": queryset.filter(status=Referral.StatusChoices.PAID).count(),
                "total_commission_pending": total_commission_pending,
                "total_commission_paid": total_commission_paid,
            },
            status=status.HTTP_200_OK,
        )


class AdminClinicReferralLinkAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)

        referral_code = assign_referral_code_if_missing(user) or user.referral_code or ""
        tenant_slug = user.tenant.slug if user.tenant_id and user.tenant else ""
        referral_link = build_referral_link(tenant_slug=tenant_slug, referral_code=referral_code)

        return Response(
            {
                "tenant_slug": tenant_slug,
                "referral_code": referral_code,
                "referral_link": referral_link,
            },
            status=status.HTTP_200_OK,
        )
