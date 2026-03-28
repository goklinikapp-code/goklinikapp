from django.contrib import admin

from .models import SessionPackage, Transaction


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ("patient", "amount", "status", "transaction_type", "due_date", "paid_at")
    list_filter = ("status", "transaction_type", "payment_method")
    search_fields = ("patient__email", "description")


@admin.register(SessionPackage)
class SessionPackageAdmin(admin.ModelAdmin):
    list_display = ("package_name", "patient", "total_sessions", "used_sessions", "total_amount")
    list_filter = ("specialty",)
