import uuid
from pathlib import Path

from django.conf import settings
from django.core.files.storage import FileSystemStorage
from django.core.files.storage import default_storage
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.users.models import GoKlinikUser

from .models import Tenant, TenantSpecialty
from .serializers import (
    PublicTenantClinicSerializer,
    TenantBrandingSerializer,
    TenantBrandingUpdateSerializer,
    TenantSpecialtySerializer,
    TenantSpecialtyWriteSerializer,
)


def resolve_tenant_for_branding(user: GoKlinikUser, tenant_id: str | None) -> Tenant | None:
    if user.role == GoKlinikUser.RoleChoices.SUPER_ADMIN:
        tenant = Tenant.objects.filter(id=tenant_id).first() if tenant_id else None
        return tenant or Tenant.objects.filter(is_active=True).order_by("created_at").first()
    return Tenant.objects.filter(id=user.tenant_id).first()


class TenantBrandingPublicAPIView(generics.RetrieveAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = TenantBrandingSerializer
    lookup_field = "slug"

    def get_queryset(self):
        return Tenant.objects.filter(is_active=True)


class PublicTenantClinicsAPIView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = PublicTenantClinicSerializer
    pagination_class = None

    def get_queryset(self):
        return Tenant.objects.filter(is_active=True).order_by("name")


class TenantBrandingUpdateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        tenant = resolve_tenant_for_branding(request.user, request.query_params.get("tenant_id"))
        if not tenant:
            return Response({"detail": "Tenant not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response(TenantBrandingSerializer(tenant).data, status=status.HTTP_200_OK)

    def put(self, request, *args, **kwargs):
        user = request.user
        if user.role not in {
            GoKlinikUser.RoleChoices.SUPER_ADMIN,
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
        }:
            return Response(status=status.HTTP_403_FORBIDDEN)

        tenant = resolve_tenant_for_branding(user, request.data.get("tenant_id"))

        if not tenant:
            return Response({"detail": "Tenant not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = TenantBrandingUpdateSerializer(tenant, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(TenantBrandingSerializer(tenant).data, status=status.HTTP_200_OK)


class TenantBrandingLogoUploadAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        user = request.user
        if user.role not in {
            GoKlinikUser.RoleChoices.SUPER_ADMIN,
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
        }:
            return Response(status=status.HTTP_403_FORBIDDEN)

        tenant = resolve_tenant_for_branding(user, request.data.get("tenant_id"))
        if not tenant:
            return Response({"detail": "Tenant not found."}, status=status.HTTP_404_NOT_FOUND)

        logo_file = request.FILES.get("logo")
        if logo_file is None:
            return Response({"detail": "Logo file is required."}, status=status.HTTP_400_BAD_REQUEST)

        content_type = (getattr(logo_file, "content_type", "") or "").lower()
        if not content_type.startswith("image/"):
            return Response({"detail": "Invalid file type."}, status=status.HTTP_400_BAD_REQUEST)

        extension = logo_file.name.split(".")[-1].lower() if "." in logo_file.name else "png"
        unique_name = f"tenant-branding/{tenant.slug}/logo-{uuid.uuid4().hex}.{extension}"

        try:
            # Avoids an S3 existence check (`HeadObject`) that may be forbidden
            # in constrained storage policies.
            saved_path = default_storage._save(unique_name, logo_file)
            logo_url = default_storage.url(saved_path)
        except Exception:
            # Fallback for local/dev environments without valid object-storage keys.
            local_root = Path(getattr(settings, "ROOT_DIR", Path.cwd())) / "media_uploads"
            fallback_storage = FileSystemStorage(
                location=str(local_root),
                base_url="/media-uploads/",
            )
            logo_file.seek(0)
            saved_path = fallback_storage.save(unique_name, logo_file)
            logo_url = fallback_storage.url(saved_path)

        if logo_url and not str(logo_url).startswith(("http://", "https://")):
            logo_url = request.build_absolute_uri(logo_url)

        tenant.logo_url = logo_url
        tenant.save(update_fields=["logo_url", "updated_at"])

        return Response(TenantBrandingSerializer(tenant).data, status=status.HTTP_200_OK)


class TenantSpecialtyListCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def _resolve_tenant(self, request):
        user = request.user
        if user.role not in {
            GoKlinikUser.RoleChoices.SUPER_ADMIN,
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
        }:
            return None, Response(status=status.HTTP_403_FORBIDDEN)
        tenant_id = request.data.get("tenant_id") if request.method != "GET" else request.query_params.get("tenant_id")
        tenant = resolve_tenant_for_branding(user, tenant_id)
        if not tenant:
            return None, Response({"detail": "Tenant not found."}, status=status.HTTP_404_NOT_FOUND)
        return tenant, None

    def get(self, request, *args, **kwargs):
        tenant, error = self._resolve_tenant(request)
        if error:
            return error

        queryset = TenantSpecialty.objects.filter(tenant=tenant).order_by("display_order", "specialty_name")
        return Response(TenantSpecialtySerializer(queryset, many=True).data, status=status.HTTP_200_OK)

    def post(self, request, *args, **kwargs):
        tenant, error = self._resolve_tenant(request)
        if error:
            return error

        serializer = TenantSpecialtyWriteSerializer(data=request.data, context={"tenant": tenant})
        serializer.is_valid(raise_exception=True)
        procedure = serializer.save(tenant=tenant)
        return Response(TenantSpecialtySerializer(procedure).data, status=status.HTTP_201_CREATED)


class TenantSpecialtyDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def _resolve_scoped_specialty(self, request, specialty_id):
        user = request.user
        if user.role not in {
            GoKlinikUser.RoleChoices.SUPER_ADMIN,
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
        }:
            return None, None, Response(status=status.HTTP_403_FORBIDDEN)
        tenant_id = request.data.get("tenant_id") if request.method != "GET" else request.query_params.get("tenant_id")
        tenant = resolve_tenant_for_branding(user, tenant_id)
        if not tenant:
            return None, None, Response({"detail": "Tenant not found."}, status=status.HTTP_404_NOT_FOUND)
        specialty = TenantSpecialty.objects.filter(id=specialty_id, tenant=tenant).first()
        return tenant, specialty, None

    def patch(self, request, specialty_id, *args, **kwargs):
        tenant, specialty, error = self._resolve_scoped_specialty(request, specialty_id)
        if error:
            return error
        if not tenant or not specialty:
            return Response({"detail": "Procedure not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = TenantSpecialtyWriteSerializer(
            specialty,
            data=request.data,
            partial=True,
            context={"tenant": tenant},
        )
        serializer.is_valid(raise_exception=True)
        updated = serializer.save()
        return Response(TenantSpecialtySerializer(updated).data, status=status.HTTP_200_OK)

    def delete(self, request, specialty_id, *args, **kwargs):
        _, specialty, error = self._resolve_scoped_specialty(request, specialty_id)
        if error:
            return error
        if not specialty:
            return Response({"detail": "Procedure not found."}, status=status.HTTP_404_NOT_FOUND)
        specialty.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
