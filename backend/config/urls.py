from pathlib import Path

from django.conf import settings
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path
from django.views.static import serve
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from apps.referrals.views import LeadAPIView, LeadDetailAPIView
from apps.users.dashboard_views import AdminDashboardAPIView


def health_view(_request):
    return JsonResponse({"status": "ok"})


urlpatterns = [
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
    path("api/post-op/", include("apps.post_op.urls")),
    path("api/chat/", include("apps.chat.urls")),
    path("api/notifications/", include("apps.notifications.urls")),
    path("api/financial/", include("apps.financial.urls")),
    path("api/referrals/", include("apps.referrals.urls")),
    path("api/referral/", include("apps.referrals.public_urls")),
    path("referral/", include("apps.referrals.public_urls")),
    path("api/medical-records/", include("apps.medical_records.urls")),
    path("api/public/", include("apps.tenants.urls")),
    path("api/admin/dashboard/", AdminDashboardAPIView.as_view(), name="api-admin-dashboard"),
    path(
        "media-uploads/<path:path>",
        serve,
        {"document_root": Path(getattr(settings, "ROOT_DIR", Path.cwd())) / "media_uploads"},
    ),
]
