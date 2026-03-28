from django.urls import path

from .views import (
    PublicTenantClinicsAPIView,
    TenantBrandingLogoUploadAPIView,
    TenantBrandingPublicAPIView,
    TenantBrandingUpdateAPIView,
    TenantSpecialtyDetailAPIView,
    TenantSpecialtyListCreateAPIView,
)

urlpatterns = [
    path(
        "tenants/clinics/",
        PublicTenantClinicsAPIView.as_view(),
        name="tenant-public-clinics",
    ),
    path(
        "tenants/<slug:slug>/branding/",
        TenantBrandingPublicAPIView.as_view(),
        name="tenant-branding-public",
    ),
    path(
        "tenants/branding/",
        TenantBrandingUpdateAPIView.as_view(),
        name="tenant-branding-update",
    ),
    path(
        "tenants/branding/logo/",
        TenantBrandingLogoUploadAPIView.as_view(),
        name="tenant-branding-logo-upload",
    ),
    path(
        "tenants/procedures/",
        TenantSpecialtyListCreateAPIView.as_view(),
        name="tenant-procedures",
    ),
    path(
        "tenants/procedures/<uuid:specialty_id>/",
        TenantSpecialtyDetailAPIView.as_view(),
        name="tenant-procedures-detail",
    ),
]
