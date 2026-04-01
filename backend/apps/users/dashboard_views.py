from __future__ import annotations

from datetime import datetime, timedelta
from decimal import Decimal

from django.db.models import Avg, Count, Max, Q, Sum
from django.db.models.functions import Coalesce
from django.utils import timezone
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import permissions, serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.appointments.models import Appointment, ProfessionalAvailability
from apps.financial.models import Transaction
from apps.patients.models import Patient
from apps.post_op.models import PostOpJourney
from apps.tenants.models import Tenant
from apps.users.models import (
    GoKlinikUser,
    SaaSClinicSignupRequest,
    SaaSSeller,
    get_saas_ai_settings,
)

from .serializers import (
    GoKlinikUserSerializer,
    SaaSClientCreateSerializer,
    SaaSClientListSerializer,
    SaaSClientUpdateSerializer,
    SaaSInviteAcceptSerializer,
    SaaSSellerCreateSerializer,
    SaaSSellerSerializer,
    SaaSAISettingsSerializer,
    SaaSSignupRequestCodeSerializer,
    SaaSSignupVerifyCodeSerializer,
)


def _get_tenant_primary_contact(tenant_id):
    return (
        GoKlinikUser.objects.filter(
            tenant_id=tenant_id,
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
        )
        .order_by("date_joined")
        .first()
    )


def _build_saas_client_payload(tenant: Tenant, *, today=None):
    today = today or timezone.localdate()
    next_30 = today + timedelta(days=30)
    primary_contact = _get_tenant_primary_contact(tenant.id)

    return {
        "id": tenant.id,
        "name": tenant.name,
        "slug": tenant.slug,
        "plan": tenant.plan,
        "is_active": tenant.is_active,
        "created_at": tenant.created_at,
        "primary_contact_name": primary_contact.full_name if primary_contact else "",
        "primary_contact_email": primary_contact.email if primary_contact else "",
        "primary_contact_phone": primary_contact.phone if primary_contact else "",
        "primary_contact_tax_number": primary_contact.cpf if primary_contact else "",
        "patients_count": Patient.objects.filter(tenant_id=tenant.id).count(),
        "appointments_next_30_days": Appointment.objects.filter(
            tenant_id=tenant.id,
            appointment_date__gte=today,
            appointment_date__lte=next_30,
        )
        .exclude(status=Appointment.StatusChoices.CANCELLED)
        .count(),
        "staff_count": GoKlinikUser.objects.filter(
            tenant_id=tenant.id,
            role__in={
                GoKlinikUser.RoleChoices.CLINIC_MASTER,
                GoKlinikUser.RoleChoices.SURGEON,
                GoKlinikUser.RoleChoices.SECRETARY,
                GoKlinikUser.RoleChoices.NURSE,
            },
        ).count(),
        "clinic_addresses": tenant.clinic_addresses or [],
    }


class DashboardTodayAppointmentSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    paciente_nome = serializers.CharField()
    horario = serializers.CharField()
    status = serializers.CharField()
    tipo = serializers.CharField()


class DashboardAlertSerializer(serializers.Serializer):
    type = serializers.CharField()
    patient_id = serializers.UUIDField()
    name = serializers.CharField()
    message = serializers.CharField()


class AdminDashboardResponseSerializer(serializers.Serializer):
    revenue_series = serializers.ListField(child=serializers.DictField(), required=False)
    specialty_distribution = serializers.ListField(child=serializers.DictField(), required=False)
    faturamento_mes_atual = serializers.DecimalField(max_digits=12, decimal_places=2)
    faturamento_mes_anterior = serializers.DecimalField(max_digits=12, decimal_places=2)
    variacao_percentual_faturamento = serializers.DecimalField(max_digits=10, decimal_places=2)
    total_pacientes_ativos = serializers.IntegerField()
    total_pacientes_inativos = serializers.IntegerField()
    novos_pacientes_mes = serializers.IntegerField()
    agendamentos_hoje = DashboardTodayAppointmentSerializer(many=True)
    taxa_ocupacao_semana = serializers.FloatField()
    ticket_medio_mes = serializers.DecimalField(max_digits=12, decimal_places=2)
    alertas = DashboardAlertSerializer(many=True)


class AdminDashboardAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(
        responses={
            status.HTTP_200_OK: AdminDashboardResponseSerializer,
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Forbidden for this role."),
            status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required."),
        }
    )
    def get(self, request):
        user = request.user
        if user.role not in {
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
            GoKlinikUser.RoleChoices.SURGEON,
        }:
            return Response(status=status.HTTP_403_FORBIDDEN)

        today = timezone.localdate()
        month_start = today.replace(day=1)
        previous_month_end = month_start - timedelta(days=1)
        previous_month_start = previous_month_end.replace(day=1)

        patients_qs = Patient.objects.all()
        appointments_qs = Appointment.objects.all()
        transactions_qs = Transaction.objects.filter(status=Transaction.StatusChoices.PAID)
        journeys_qs = PostOpJourney.objects.filter(status=PostOpJourney.StatusChoices.ACTIVE)

        if user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            patients_qs = patients_qs.filter(tenant_id=user.tenant_id)
            appointments_qs = appointments_qs.filter(tenant_id=user.tenant_id)
            transactions_qs = transactions_qs.filter(tenant_id=user.tenant_id)
            journeys_qs = journeys_qs.filter(patient__tenant_id=user.tenant_id)

        faturamento_mes_atual = transactions_qs.filter(
            paid_at__date__gte=month_start,
            paid_at__date__lte=today,
        ).aggregate(v=Coalesce(Sum("amount"), Decimal("0.00")))["v"]

        faturamento_mes_anterior = transactions_qs.filter(
            paid_at__date__gte=previous_month_start,
            paid_at__date__lte=previous_month_end,
        ).aggregate(v=Coalesce(Sum("amount"), Decimal("0.00")))["v"]

        variacao_percentual_faturamento = Decimal("0.00")
        if faturamento_mes_anterior and faturamento_mes_anterior != 0:
            variacao_percentual_faturamento = (
                (faturamento_mes_atual - faturamento_mes_anterior) / faturamento_mes_anterior
            ) * Decimal("100")

        total_pacientes_ativos = patients_qs.filter(status=Patient.StatusChoices.ACTIVE).count()
        total_pacientes_inativos = patients_qs.filter(status=Patient.StatusChoices.INACTIVE).count()
        novos_pacientes_mes = patients_qs.filter(date_joined__date__gte=month_start).count()

        now = timezone.localtime()
        agendamentos_hoje = [
            {
                "id": str(item.id),
                "paciente_nome": item.patient.full_name,
                "horario": item.appointment_time.strftime("%H:%M"),
                "status": item.status,
                "tipo": item.appointment_type,
            }
            for item in appointments_qs.filter(
                appointment_date=today,
                appointment_time__gte=now.time(),
            )
            .select_related("patient")
            .order_by("appointment_time")[:25]
        ]

        next_week_end = today + timedelta(days=7)
        upcoming_qs = appointments_qs.filter(
            appointment_date__gte=today,
            appointment_date__lte=next_week_end,
        )

        professionals = GoKlinikUser.objects.filter(role=GoKlinikUser.RoleChoices.SURGEON)
        if user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            professionals = professionals.filter(tenant_id=user.tenant_id)

        availability = ProfessionalAvailability.objects.filter(
            professional__in=professionals,
            is_active=True,
        )

        total_slots = 0
        for entry in availability:
            for day_offset in range(0, 7):
                date = today + timedelta(days=day_offset)
                if date.weekday() != entry.day_of_week:
                    continue
                start_dt = datetime.combine(date, entry.start_time)
                end_dt = datetime.combine(date, entry.end_time)
                minutes = max((end_dt - start_dt).seconds // 60, 0)
                total_slots += minutes // 60

        filled_slots = upcoming_qs.exclude(status=Appointment.StatusChoices.CANCELLED).count()
        taxa_ocupacao_semana = 0
        if total_slots > 0:
            taxa_ocupacao_semana = round((filled_slots / total_slots) * 100, 2)

        ticket_medio_mes = transactions_qs.filter(
            paid_at__date__gte=month_start,
            paid_at__date__lte=today,
        ).aggregate(v=Coalesce(Avg("amount"), Decimal("0.00")))["v"]

        alerts: list[dict] = []

        inactivity_cutoff = today - timedelta(days=180)
        inactive_patients = patients_qs.annotate(
            last_appointment=Max("appointments__appointment_date")
        ).filter(last_appointment__lt=inactivity_cutoff)[:20]
        for p in inactive_patients:
            alerts.append(
                {
                    "type": "inactive_patient",
                    "patient_id": str(p.id),
                    "name": p.full_name,
                    "message": "Patient has been inactive for more than 6 months.",
                }
            )

        postop_pending = journeys_qs.filter(surgery_date__lt=today - timedelta(days=7))[:20]
        for j in postop_pending:
            alerts.append(
                {
                    "type": "postop_pending",
                    "patient_id": str(j.patient_id),
                    "name": j.patient.full_name,
                    "message": "Active post-op journey pending return follow-up.",
                }
            )

        birthday_today = patients_qs.filter(
            date_of_birth__month=today.month,
            date_of_birth__day=today.day,
        )[:20]
        for p in birthday_today:
            alerts.append(
                {
                    "type": "birthday",
                    "patient_id": str(p.id),
                    "name": p.full_name,
                    "message": "Patient birthday today.",
                }
            )

        revenue_series: list[dict] = []
        for offset in range(5, -1, -1):
            target_year = month_start.year
            target_month = month_start.month - offset
            while target_month <= 0:
                target_month += 12
                target_year -= 1

            window_start = month_start.replace(year=target_year, month=target_month, day=1)
            if window_start.month == 12:
                window_end = window_start.replace(year=window_start.year + 1, month=1, day=1)
            else:
                window_end = window_start.replace(month=window_start.month + 1, day=1)

            total = transactions_qs.filter(
                paid_at__date__gte=window_start,
                paid_at__date__lt=window_end,
            ).aggregate(v=Coalesce(Sum("amount"), Decimal("0.00")))["v"]

            projected = (total * Decimal("1.08")).quantize(Decimal("0.01"))
            revenue_series.append(
                {
                    "name": window_start.strftime("%b"),
                    "atual": total,
                    "projetado": projected,
                }
            )

        specialty_distribution: list[dict] = []
        color_scale = ["#0D5C73", "#4A7C59", "#C8992E", "#1A1F2E", "#059669"]
        specialty_agg = list(
            patients_qs.exclude(specialty__specialty_name__isnull=True)
            .exclude(specialty__specialty_name="")
            .values("specialty__specialty_name")
            .annotate(total=Count("id"))
            .order_by("-total")[:5]
        )
        specialty_total = sum(item["total"] for item in specialty_agg) or 1
        for index, item in enumerate(specialty_agg):
            specialty_distribution.append(
                {
                    "name": item["specialty__specialty_name"],
                    "value": round((item["total"] / specialty_total) * 100, 2),
                    "color": color_scale[index % len(color_scale)],
                }
            )

        return Response(
            {
                "revenue_series": revenue_series,
                "specialty_distribution": specialty_distribution,
                "faturamento_mes_atual": faturamento_mes_atual,
                "faturamento_mes_anterior": faturamento_mes_anterior,
                "variacao_percentual_faturamento": round(variacao_percentual_faturamento, 2),
                "total_pacientes_ativos": total_pacientes_ativos,
                "total_pacientes_inativos": total_pacientes_inativos,
                "novos_pacientes_mes": novos_pacientes_mes,
                "agendamentos_hoje": agendamentos_hoje,
                "taxa_ocupacao_semana": taxa_ocupacao_semana,
                "ticket_medio_mes": ticket_medio_mes,
                "alertas": alerts,
            }
        )


class SaaSDashboardRecentClientSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    name = serializers.CharField()
    slug = serializers.CharField()
    plan = serializers.CharField()
    is_active = serializers.BooleanField()
    created_at = serializers.DateTimeField()
    primary_contact_name = serializers.CharField(allow_blank=True)
    primary_contact_email = serializers.EmailField(allow_blank=True)


class SaaSDashboardTopSellerSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    full_name = serializers.CharField()
    invites_sent = serializers.IntegerField()
    invites_accepted = serializers.IntegerField()
    signups_completed = serializers.IntegerField()


class SaaSDashboardResponseSerializer(serializers.Serializer):
    total_clinics = serializers.IntegerField()
    active_clinics = serializers.IntegerField()
    inactive_clinics = serializers.IntegerField()
    new_clinics_this_month = serializers.IntegerField()
    clinic_master_users = serializers.IntegerField()
    clinical_staff_users = serializers.IntegerField()
    total_patients = serializers.IntegerField()
    total_appointments_this_month = serializers.IntegerField()
    total_revenue_this_month = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_sellers = serializers.IntegerField()
    active_sellers = serializers.IntegerField()
    seller_invites_sent = serializers.IntegerField()
    seller_invites_accepted = serializers.IntegerField()
    seller_signups_completed = serializers.IntegerField()
    top_sellers = SaaSDashboardTopSellerSerializer(many=True)
    recent_clients = SaaSDashboardRecentClientSerializer(many=True)


class SaaSDashboardAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(
        responses={
            status.HTTP_200_OK: SaaSDashboardResponseSerializer,
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can access this endpoint."),
            status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required."),
        }
    )
    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        today = timezone.localdate()
        month_start = today.replace(day=1)

        tenants_qs = Tenant.objects.all()

        total_clinics = tenants_qs.count()
        active_clinics = tenants_qs.filter(is_active=True).count()
        inactive_clinics = max(total_clinics - active_clinics, 0)
        new_clinics_this_month = tenants_qs.filter(created_at__date__gte=month_start).count()

        clinic_master_users = GoKlinikUser.objects.filter(
            role=GoKlinikUser.RoleChoices.CLINIC_MASTER
        ).count()
        clinical_staff_users = GoKlinikUser.objects.filter(
            role__in={
                GoKlinikUser.RoleChoices.CLINIC_MASTER,
                GoKlinikUser.RoleChoices.SURGEON,
                GoKlinikUser.RoleChoices.SECRETARY,
                GoKlinikUser.RoleChoices.NURSE,
            }
        ).count()

        total_patients = Patient.objects.count()
        total_appointments_this_month = Appointment.objects.filter(
            appointment_date__gte=month_start,
            appointment_date__lte=today,
        ).count()
        total_revenue_this_month = Transaction.objects.filter(
            status=Transaction.StatusChoices.PAID,
            paid_at__date__gte=month_start,
            paid_at__date__lte=today,
        ).aggregate(v=Coalesce(Sum("amount"), Decimal("0.00")))["v"]

        seller_qs = SaaSSeller.objects.all()
        total_sellers = seller_qs.count()
        active_sellers = seller_qs.filter(is_active=True).count()

        seller_signup_qs = SaaSClinicSignupRequest.objects.filter(
            seller__isnull=False,
        )
        seller_invites_sent = seller_signup_qs.count()
        seller_invites_accepted = seller_signup_qs.filter(
            status=SaaSClinicSignupRequest.StatusChoices.VERIFIED
        ).count()
        seller_signups_completed = seller_invites_accepted

        recent_clients: list[dict] = []
        for tenant in tenants_qs.order_by("-created_at")[:8]:
            master = _get_tenant_primary_contact(tenant.id)
            recent_clients.append(
                {
                    "id": tenant.id,
                    "name": tenant.name,
                    "slug": tenant.slug,
                    "plan": tenant.plan,
                    "is_active": tenant.is_active,
                    "created_at": tenant.created_at,
                    "primary_contact_name": master.full_name if master else "",
                    "primary_contact_email": master.email if master else "",
                }
            )

        top_sellers_qs = (
            seller_qs.annotate(
                invites_sent=Count(
                    "signup_requests",
                ),
                invites_accepted=Count(
                    "signup_requests",
                    filter=Q(signup_requests__status=SaaSClinicSignupRequest.StatusChoices.VERIFIED),
                ),
            )
            .order_by("-invites_accepted", "-invites_sent", "full_name")[:5]
        )
        top_sellers = [
            {
                "id": seller.id,
                "full_name": seller.full_name,
                "invites_sent": seller.invites_sent,
                "invites_accepted": seller.invites_accepted,
                "signups_completed": seller.invites_accepted,
            }
            for seller in top_sellers_qs
        ]

        return Response(
            {
                "total_clinics": total_clinics,
                "active_clinics": active_clinics,
                "inactive_clinics": inactive_clinics,
                "new_clinics_this_month": new_clinics_this_month,
                "clinic_master_users": clinic_master_users,
                "clinical_staff_users": clinical_staff_users,
                "total_patients": total_patients,
                "total_appointments_this_month": total_appointments_this_month,
                "total_revenue_this_month": total_revenue_this_month,
                "total_sellers": total_sellers,
                "active_sellers": active_sellers,
                "seller_invites_sent": seller_invites_sent,
                "seller_invites_accepted": seller_invites_accepted,
                "seller_signups_completed": seller_signups_completed,
                "top_sellers": top_sellers,
                "recent_clients": recent_clients,
            }
        )


class SaaSClientsAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(
        responses={
            status.HTTP_200_OK: SaaSClientListSerializer(many=True),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can access this endpoint."),
            status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required."),
        }
    )
    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        today = timezone.localdate()
        payload = [
            _build_saas_client_payload(tenant, today=today)
            for tenant in Tenant.objects.all().order_by("-created_at")
        ]
        return Response(payload)

    @extend_schema(
        request=SaaSClientCreateSerializer,
        responses={
            status.HTTP_201_CREATED: OpenApiResponse(description="Client created or invite sent."),
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can create clients."),
            status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required."),
        },
    )
    def post(self, request):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = SaaSClientCreateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        created = serializer.save()

        if created.get("mode") == SaaSClientCreateSerializer.ModeChoices.INVITE:
            return Response(
                {
                    "mode": "invite",
                    "invite_request_id": created["invite_request_id"],
                    "invite_token": created["invite_token"],
                    "detail": "Convite enviado para o e-mail da clínica.",
                },
                status=status.HTTP_201_CREATED,
            )

        tenant = created["tenant"]
        return Response(
            _build_saas_client_payload(tenant, today=timezone.localdate()),
            status=status.HTTP_201_CREATED,
        )


class SaaSClientDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def _get_tenant(self, client_id):
        return Tenant.objects.filter(id=client_id).first()

    @extend_schema(
        responses={
            status.HTTP_200_OK: SaaSClientListSerializer,
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can access this endpoint."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Client not found."),
        }
    )
    def get(self, request, client_id):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        tenant = self._get_tenant(client_id)
        if not tenant:
            return Response(status=status.HTTP_404_NOT_FOUND)

        return Response(_build_saas_client_payload(tenant, today=timezone.localdate()))

    @extend_schema(
        request=SaaSClientUpdateSerializer,
        responses={
            status.HTTP_200_OK: SaaSClientListSerializer,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can update clients."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Client not found."),
        },
    )
    def patch(self, request, client_id):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        tenant = self._get_tenant(client_id)
        if not tenant:
            return Response(status=status.HTTP_404_NOT_FOUND)

        owner = _get_tenant_primary_contact(tenant.id)
        serializer = SaaSClientUpdateSerializer(
            data=request.data,
            partial=True,
            context={"owner": owner},
        )
        serializer.is_valid(raise_exception=True)
        updated_tenant = serializer.update_client(tenant=tenant, owner=owner)
        return Response(_build_saas_client_payload(updated_tenant, today=timezone.localdate()))

    @extend_schema(
        responses={
            status.HTTP_204_NO_CONTENT: OpenApiResponse(description="Client disabled."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can disable clients."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Client not found."),
        }
    )
    def delete(self, request, client_id):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        tenant = self._get_tenant(client_id)
        if not tenant:
            return Response(status=status.HTTP_404_NOT_FOUND)

        tenant.is_active = False
        tenant.save(update_fields=["is_active", "updated_at"])
        GoKlinikUser.objects.filter(tenant_id=tenant.id).update(is_active=False)
        return Response(status=status.HTTP_204_NO_CONTENT)


class SaaSSellersAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(
        responses={
            status.HTTP_200_OK: SaaSSellerSerializer(many=True),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can access this endpoint."),
            status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required."),
        }
    )
    def get(self, request):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        sellers = SaaSSeller.objects.all().order_by("full_name")
        return Response(SaaSSellerSerializer(sellers, many=True).data)

    @extend_schema(
        request=SaaSSellerCreateSerializer,
        responses={
            status.HTTP_201_CREATED: SaaSSellerSerializer,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can create sellers."),
        },
    )
    def post(self, request):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = SaaSSellerCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        seller = serializer.save()
        return Response(SaaSSellerSerializer(seller).data, status=status.HTTP_201_CREATED)


class SaaSSellerDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def _get_seller(self, seller_id):
        return SaaSSeller.objects.filter(id=seller_id).first()

    @extend_schema(
        responses={
            status.HTTP_200_OK: SaaSSellerSerializer,
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can access this endpoint."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Seller not found."),
        }
    )
    def get(self, request, seller_id):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        seller = self._get_seller(seller_id)
        if not seller:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(SaaSSellerSerializer(seller).data)

    @extend_schema(
        request=SaaSSellerCreateSerializer,
        responses={
            status.HTTP_200_OK: SaaSSellerSerializer,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can update sellers."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Seller not found."),
        },
    )
    def patch(self, request, seller_id):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        seller = self._get_seller(seller_id)
        if not seller:
            return Response(status=status.HTTP_404_NOT_FOUND)

        serializer = SaaSSellerCreateSerializer(seller, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        updated = serializer.save()
        return Response(SaaSSellerSerializer(updated).data)

    @extend_schema(
        responses={
            status.HTTP_204_NO_CONTENT: OpenApiResponse(description="Seller deleted."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can delete sellers."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Seller not found."),
        }
    )
    def delete(self, request, seller_id):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        seller = self._get_seller(seller_id)
        if not seller:
            return Response(status=status.HTTP_404_NOT_FOUND)

        seller.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class SaaSSignupRequestCodeAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    @extend_schema(
        request=SaaSSignupRequestCodeSerializer,
        responses={
            status.HTTP_201_CREATED: OpenApiResponse(description="Verification code sent."),
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
        },
    )
    def post(self, request):
        serializer = SaaSSignupRequestCodeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        signup_request = serializer.save()
        return Response(
            {
                "detail": "Código enviado para o e-mail informado.",
                "email": signup_request.owner_email,
                "request_id": str(signup_request.id),
                "expires_in_minutes": 15,
            },
            status=status.HTTP_201_CREATED,
        )


class SaaSSignupVerifyCodeAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    @extend_schema(
        request=SaaSSignupVerifyCodeSerializer,
        responses={
            status.HTTP_201_CREATED: OpenApiResponse(description="Clinic account created."),
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
        },
    )
    def post(self, request):
        serializer = SaaSSignupVerifyCodeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access_token": str(refresh.access_token),
                "refresh_token": str(refresh),
                "user": GoKlinikUserSerializer(
                    user,
                    context={"request": request},
                ).data,
            },
            status=status.HTTP_201_CREATED,
        )


class SaaSInvitePreviewSerializer(serializers.Serializer):
    clinic_name = serializers.CharField()
    owner_full_name = serializers.CharField()
    owner_email = serializers.EmailField()
    plan = serializers.CharField()
    expires_at = serializers.DateTimeField(allow_null=True)


class SaaSInvitePreviewAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    @extend_schema(
        responses={
            status.HTTP_200_OK: SaaSInvitePreviewSerializer,
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Invalid or expired invite."),
        },
    )
    def get(self, request, token):
        signup_request = SaaSClinicSignupRequest.objects.filter(
            invite_token=token,
            flow=SaaSClinicSignupRequest.FlowChoices.SAAS_INVITE,
            status=SaaSClinicSignupRequest.StatusChoices.PENDING,
        ).first()
        if not signup_request:
            return Response(status=status.HTTP_404_NOT_FOUND)

        if signup_request.verification_expires_at and signup_request.verification_expires_at < timezone.now():
            signup_request.status = SaaSClinicSignupRequest.StatusChoices.EXPIRED
            signup_request.save(update_fields=["status", "updated_at"])
            return Response(status=status.HTTP_404_NOT_FOUND)

        return Response(
            {
                "clinic_name": signup_request.clinic_name,
                "owner_full_name": signup_request.owner_full_name,
                "owner_email": signup_request.owner_email,
                "plan": signup_request.plan,
                "expires_at": signup_request.verification_expires_at,
            }
        )


class SaaSInviteAcceptAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    @extend_schema(
        request=SaaSInviteAcceptSerializer,
        responses={
            status.HTTP_201_CREATED: OpenApiResponse(description="Clinic account created."),
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
        },
    )
    def post(self, request):
        serializer = SaaSInviteAcceptSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access_token": str(refresh.access_token),
                "refresh_token": str(refresh),
                "user": GoKlinikUserSerializer(
                    user,
                    context={"request": request},
                ).data,
            },
            status=status.HTTP_201_CREATED,
        )


class SaaSSellerLookupAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, code):
        seller = SaaSSeller.objects.filter(invite_code=(code or "").strip().upper(), is_active=True).first()
        if not seller:
            return Response(status=status.HTTP_404_NOT_FOUND)

        return Response(
            {
                "full_name": seller.full_name,
                "invite_code": seller.invite_code,
            }
        )


class SaaSAISettingsAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def _forbidden_if_not_super_admin(self, request):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)
        return None

    def get(self, request):
        forbidden = self._forbidden_if_not_super_admin(request)
        if forbidden:
            return forbidden

        settings = get_saas_ai_settings()
        return Response(SaaSAISettingsSerializer(settings).data, status=status.HTTP_200_OK)

    def patch(self, request):
        forbidden = self._forbidden_if_not_super_admin(request)
        if forbidden:
            return forbidden

        settings = get_saas_ai_settings()
        serializer = SaaSAISettingsSerializer(settings, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(SaaSAISettingsSerializer(settings).data, status=status.HTTP_200_OK)
