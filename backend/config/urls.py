from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path
from django.views.static import serve
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from apps.pre_operatory.views import (
    PreOperatoryCreateAPIView,
    PreOperatoryDetailAPIView,
    PreOperatoryFileDetailAPIView,
    PreOperatoryMeAPIView,
    PreOperatoryPatientAPIView,
)
from apps.post_op.views import (
    UrgentTicketListCreateAPIView,
    UrgentTicketStatusUpdateAPIView,
)
from apps.referrals.views import LeadAPIView, LeadDetailAPIView
from apps.users.dashboard_views import AdminDashboardAPIView


def health_view(_request):
    return JsonResponse({"status": "ok"})


urlpatterns = [
    path("api/pre-operatory", PreOperatoryCreateAPIView.as_view(), name="api-pre-operatory"),
    path("api/pre-operatory/", PreOperatoryCreateAPIView.as_view(), name="api-pre-operatory-slash"),
    path("api/pre-operatory/me", PreOperatoryMeAPIView.as_view(), name="api-pre-operatory-me"),
    path(
        "api/pre-operatory/files/<uuid:file_id>",
        PreOperatoryFileDetailAPIView.as_view(),
        name="api-pre-operatory-file-detail",
    ),
    path(
        "api/pre-operatory/patient/<uuid:patient_id>",
        PreOperatoryPatientAPIView.as_view(),
        name="api-pre-operatory-patient",
    ),
    path(
        "api/pre-operatory/patient/<uuid:patient_id>/",
        PreOperatoryPatientAPIView.as_view(),
        name="api-pre-operatory-patient-slash",
    ),
    path(
        "api/pre-operatory/<uuid:pre_operatory_id>",
        PreOperatoryDetailAPIView.as_view(),
        name="api-pre-operatory-detail",
    ),
    path(
        "api/pre-operatory/<uuid:pre_operatory_id>/",
        PreOperatoryDetailAPIView.as_view(),
        name="api-pre-operatory-detail-slash",
    ),
    path("pre-operatory", PreOperatoryCreateAPIView.as_view(), name="pre-operatory"),
    path("pre-operatory/me", PreOperatoryMeAPIView.as_view(), name="pre-operatory-me"),
    path(
        "pre-operatory/<uuid:pre_operatory_id>",
        PreOperatoryDetailAPIView.as_view(),
        name="pre-operatory-detail",
    ),
    path("api/leads", LeadAPIView.as_view(), name="api-leads"),
    path("api/leads/<uuid:lead_id>/", LeadDetailAPIView.as_view(), name="api-lead-detail"),
    path("leads", LeadAPIView.as_view(), name="leads"),
    path("leads/<uuid:lead_id>/", LeadDetailAPIView.as_view(), name="lead-detail"),
    path("admin/", admin.site.urls),
    path("api/health/", health_view, name="api-health"),
    path("api/schema/", SpectacularAPIView.as_view(), name="api-schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="api-schema"), name="api-docs"),
    path("api/auth/", include("apps.users.urls")),
    path("api/patients/", include("apps.patients.urls")),
    path("api/appointments/", include("apps.appointments.urls")),
    path(
        "api/urgent-tickets",
        UrgentTicketListCreateAPIView.as_view(),
        name="api-urgent-tickets-noslash",
    ),
    path(
        "api/urgent-tickets/",
        UrgentTicketListCreateAPIView.as_view(),
        name="api-urgent-tickets",
    ),
    path(
        "api/urgent-tickets/<uuid:ticket_id>",
        UrgentTicketStatusUpdateAPIView.as_view(),
        name="api-urgent-ticket-detail-noslash",
    ),
    path(
        "api/urgent-tickets/<uuid:ticket_id>/",
        UrgentTicketStatusUpdateAPIView.as_view(),
        name="api-urgent-ticket-detail",
    ),
    path("api/post-op/", include("apps.post_op.urls")),
    path("api/post-operatory/", include("apps.post_op.urls")),
    path("api/chat/", include("apps.chat.urls")),
    path("api/notifications/", include("apps.notifications.urls")),
    path("api/financial/", include("apps.financial.urls")),
    path("api/referrals/", include("apps.referrals.urls")),
    path("api/referral/", include("apps.referrals.public_urls")),
    path("referral/", include("apps.referrals.public_urls")),
    path("api/medical-records/", include("apps.medical_records.urls")),
    path("api/travel-plans/", include("apps.travel_plans.urls")),
    path("api/public/", include("apps.tenants.urls")),
    path("api/admin/dashboard/", AdminDashboardAPIView.as_view(), name="api-admin-dashboard"),
    path("media/<path:path>", serve, {"document_root": settings.MEDIA_ROOT}),
    path(
        "media-uploads/<path:path>",
        serve,
        {"document_root": settings.MEDIA_ROOT},
    ),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
