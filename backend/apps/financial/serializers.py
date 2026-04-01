from __future__ import annotations

from rest_framework import serializers

from config.media_urls import AbsoluteMediaUrlsSerializerMixin

from apps.appointments.models import Appointment
from apps.patients.models import Patient

from .models import SessionPackage, Transaction


class TransactionListSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    patient = serializers.SerializerMethodField()

    class Meta:
        model = Transaction
        fields = (
            "id",
            "patient",
            "description",
            "amount",
            "status",
            "due_date",
            "paid_at",
            "payment_method",
            "transaction_type",
            "created_at",
        )

    def get_patient(self, obj):
        return {
            "id": str(obj.patient_id),
            "name": obj.patient.full_name,
            "avatar": obj.patient.avatar_url,
        }


class TransactionCreateSerializer(serializers.Serializer):
    patient_id = serializers.UUIDField()
    appointment_id = serializers.UUIDField(required=False, allow_null=True)
    description = serializers.CharField()
    amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    transaction_type = serializers.ChoiceField(choices=Transaction.TransactionTypeChoices.choices)
    due_date = serializers.DateField()
    payment_method = serializers.ChoiceField(choices=Transaction.PaymentMethodChoices.choices)
    notes = serializers.CharField(required=False, allow_blank=True, default="")

    def validate(self, attrs):
        request = self.context["request"]
        user = request.user

        patient = Patient.objects.filter(id=attrs["patient_id"]).first()
        if not patient:
            raise serializers.ValidationError({"patient_id": "Patient not found."})
        if patient.tenant_id != user.tenant_id:
            raise serializers.ValidationError({"patient_id": "Patient must belong to your tenant."})
        attrs["patient"] = patient

        appointment_id = attrs.get("appointment_id")
        if appointment_id:
            appointment = Appointment.objects.filter(id=appointment_id).first()
            if not appointment:
                raise serializers.ValidationError({"appointment_id": "Appointment not found."})
            if appointment.tenant_id != user.tenant_id:
                raise serializers.ValidationError(
                    {"appointment_id": "Appointment must belong to your tenant."}
                )
            attrs["appointment"] = appointment
        else:
            attrs["appointment"] = None

        return attrs


class SessionPackageSerializer(serializers.ModelSerializer):
    specialty = serializers.SerializerMethodField()
    sessions_remaining = serializers.SerializerMethodField()

    class Meta:
        model = SessionPackage
        fields = (
            "id",
            "package_name",
            "specialty",
            "total_sessions",
            "used_sessions",
            "sessions_remaining",
            "total_amount",
            "purchase_date",
        )

    def get_specialty(self, obj):
        if not obj.specialty:
            return None
        return {"id": str(obj.specialty_id), "name": obj.specialty.specialty_name}

    def get_sessions_remaining(self, obj):
        return max(obj.total_sessions - obj.used_sessions, 0)
