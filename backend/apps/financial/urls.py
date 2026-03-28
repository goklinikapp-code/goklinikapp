from django.urls import path

from .views import (
    AdminTransactionsAPIView,
    FinancialDashboardAPIView,
    MarkPaidAPIView,
    MyPackagesAPIView,
    MyTransactionsAPIView,
    TransactionCreateAPIView,
)

urlpatterns = [
    path("my-transactions/", MyTransactionsAPIView.as_view(), name="financial-my-transactions"),
    path("my-packages/", MyPackagesAPIView.as_view(), name="financial-my-packages"),
    path("admin/transactions/", AdminTransactionsAPIView.as_view(), name="financial-admin-transactions"),
    path("transactions/", TransactionCreateAPIView.as_view(), name="financial-transactions-create"),
    path("transactions/<uuid:transaction_id>/mark-paid/", MarkPaidAPIView.as_view(), name="financial-transactions-mark-paid"),
    path("admin/dashboard/", FinancialDashboardAPIView.as_view(), name="financial-admin-dashboard"),
]
