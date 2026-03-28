from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.db.models import Avg, Sum
from django.db.models.functions import Coalesce
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.users.models import GoKlinikUser

from .models import SessionPackage, Transaction
from .serializers import (
    SessionPackageSerializer,
    TransactionCreateSerializer,
    TransactionListSerializer,
)


class AdminTransactionsPagination(PageNumberPagination):
    page_size = 25


class MyTransactionsAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        queryset = Transaction.objects.filter(patient_id=user.id).select_related("patient").order_by("-created_at")
        next_due = (
            queryset.filter(status=Transaction.StatusChoices.PENDING)
            .order_by("due_date", "created_at")
            .first()
        )
        open_balance = queryset.filter(status=Transaction.StatusChoices.PENDING).aggregate(
            total=Coalesce(Sum("amount"), Decimal("0.00"))
        )["total"]

        return Response(
            {
                "next_due": (
                    {
                        "id": str(next_due.id),
                        "description": next_due.description,
                        "amount": next_due.amount,
                        "due_date": next_due.due_date,
                    }
                    if next_due
                    else None
                ),
                "open_balance": open_balance,
                "transactions": TransactionListSerializer(queryset, many=True).data,
            },
            status=status.HTTP_200_OK,
        )


class MyPackagesAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        packages = (
            SessionPackage.objects.filter(patient_id=user.id)
            .select_related("specialty")
            .order_by("-purchase_date")
        )
        return Response(SessionPackageSerializer(packages, many=True).data, status=status.HTTP_200_OK)


class AdminTransactionsAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role not in {GoKlinikUser.RoleChoices.CLINIC_MASTER, GoKlinikUser.RoleChoices.SURGEON}:
            return Response(status=status.HTTP_403_FORBIDDEN)

        queryset = Transaction.objects.filter(tenant_id=user.tenant_id).select_related("patient")

        patient_id = request.query_params.get("patient_id")
        status_filter = request.query_params.get("status")
        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")

        if patient_id:
            queryset = queryset.filter(patient_id=patient_id)
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        if date_from:
            queryset = queryset.filter(due_date__gte=date_from)
        if date_to:
            queryset = queryset.filter(due_date__lte=date_to)

        queryset = queryset.order_by("-created_at")
        paginator = AdminTransactionsPagination()
        page = paginator.paginate_queryset(queryset, request)
        serializer = TransactionListSerializer(page, many=True)
        return paginator.get_paginated_response(serializer.data)


class TransactionCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        if user.role not in {GoKlinikUser.RoleChoices.CLINIC_MASTER, GoKlinikUser.RoleChoices.SECRETARY}:
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = TransactionCreateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        payload = serializer.validated_data

        transaction = Transaction.objects.create(
            tenant_id=user.tenant_id,
            patient=payload["patient"],
            appointment=payload["appointment"],
            description=payload["description"],
            amount=payload["amount"],
            transaction_type=payload["transaction_type"],
            due_date=payload["due_date"],
            payment_method=payload["payment_method"],
            notes=payload.get("notes", ""),
            status=Transaction.StatusChoices.PENDING,
        )
        data = TransactionListSerializer(transaction).data
        return Response(data, status=status.HTTP_201_CREATED)


class MarkPaidAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, transaction_id):
        user = request.user
        if user.role not in {GoKlinikUser.RoleChoices.CLINIC_MASTER, GoKlinikUser.RoleChoices.SECRETARY}:
            return Response(status=status.HTTP_403_FORBIDDEN)

        transaction = (
            Transaction.objects.filter(id=transaction_id, tenant_id=user.tenant_id)
            .select_related("patient")
            .first()
        )
        if not transaction:
            return Response({"detail": "Transaction not found."}, status=status.HTTP_404_NOT_FOUND)

        transaction.status = Transaction.StatusChoices.PAID
        transaction.paid_at = timezone.now()
        transaction.save(update_fields=["status", "paid_at"])

        return Response(TransactionListSerializer(transaction).data, status=status.HTTP_200_OK)


class FinancialDashboardAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)

        today = timezone.localdate()
        month_start = today.replace(day=1)
        previous_month_end = month_start - timedelta(days=1)
        previous_month_start = previous_month_end.replace(day=1)

        transactions = Transaction.objects.filter(tenant_id=user.tenant_id)

        current_paid = transactions.filter(
            status=Transaction.StatusChoices.PAID,
            paid_at__date__gte=month_start,
            paid_at__date__lte=today,
        )
        previous_paid = transactions.filter(
            status=Transaction.StatusChoices.PAID,
            paid_at__date__gte=previous_month_start,
            paid_at__date__lte=previous_month_end,
        )

        faturamento_mes_atual = current_paid.aggregate(v=Coalesce(Sum("amount"), Decimal("0.00")))["v"]
        faturamento_mes_anterior = previous_paid.aggregate(v=Coalesce(Sum("amount"), Decimal("0.00")))["v"]
        ticket_medio_mes = current_paid.aggregate(v=Coalesce(Avg("amount"), Decimal("0.00")))["v"]
        total_pendente = transactions.filter(status=Transaction.StatusChoices.PENDING).aggregate(
            v=Coalesce(Sum("amount"), Decimal("0.00"))
        )["v"]
        transacoes_pendentes_count = transactions.filter(
            status=Transaction.StatusChoices.PENDING
        ).count()

        variacao_percentual = Decimal("0.00")
        if faturamento_mes_anterior:
            variacao_percentual = (
                (faturamento_mes_atual - faturamento_mes_anterior) / faturamento_mes_anterior
            ) * Decimal("100")

        return Response(
            {
                "faturamento_mes_atual": faturamento_mes_atual,
                "faturamento_mes_anterior": faturamento_mes_anterior,
                "variacao_percentual": round(variacao_percentual, 2),
                "ticket_medio_mes": ticket_medio_mes,
                "total_pendente": total_pendente,
                "transacoes_pendentes_count": transacoes_pendentes_count,
            },
            status=status.HTTP_200_OK,
        )
