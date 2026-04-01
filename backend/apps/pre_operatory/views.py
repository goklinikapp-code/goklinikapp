from __future__ import annotations

import uuid
from pathlib import Path
from urllib.parse import urlsplit

from django.conf import settings
from django.core.files.storage import FileSystemStorage
from django.core.files.storage import default_storage
from django.db import transaction
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from config.media_urls import absolute_media_url

from apps.users.models import GoKlinikUser

from .models import PreOperatory, PreOperatoryFile
from .serializers import PreOperatorySerializer, PreOperatoryWriteSerializer


def _save_uploaded_file(*, request, upload, folder: str) -> str:
    original_name = getattr(upload, "name", "") or ""
    suffix = Path(original_name).suffix.lower()[:10]
    filename = f"{uuid.uuid4()}{suffix}"
    storage_path = f"{folder}/{filename}"
    try:
        saved_path = default_storage.save(storage_path, upload)
        file_url = default_storage.url(saved_path)
    except Exception:
        media_root = Path(getattr(settings, "MEDIA_ROOT", Path.cwd()))
        base_url = getattr(settings, "MEDIA_URL", "/media/")
        fallback_storage = FileSystemStorage(
            location=str(media_root),
            base_url=base_url,
        )
        if hasattr(upload, "seek"):
            upload.seek(0)
        saved_path = fallback_storage.save(storage_path, upload)
        file_url = fallback_storage.url(saved_path)
    return absolute_media_url(file_url, request=request)


def _active_pre_operatory_for_patient(user: GoKlinikUser) -> PreOperatory | None:
    return (
        PreOperatory.objects.filter(
            patient_id=user.id,
            status__in=[
                PreOperatory.StatusChoices.PENDING,
                PreOperatory.StatusChoices.IN_REVIEW,
                PreOperatory.StatusChoices.APPROVED,
            ],
        )
        .prefetch_related("files")
        .first()
    )


def _can_staff_view_patient_pre_operatory(user: GoKlinikUser, patient: GoKlinikUser) -> bool:
    if user.role == GoKlinikUser.RoleChoices.SUPER_ADMIN:
        return True

    if user.role in {
        GoKlinikUser.RoleChoices.CLINIC_MASTER,
        GoKlinikUser.RoleChoices.SURGEON,
        GoKlinikUser.RoleChoices.NURSE,
        GoKlinikUser.RoleChoices.SECRETARY,
    }:
        return str(user.tenant_id or "") == str(patient.tenant_id or "")

    return False


def _can_manage_pre_operatory_file(user: GoKlinikUser, pre_operatory: PreOperatory) -> bool:
    if user.role == GoKlinikUser.RoleChoices.PATIENT:
        return str(user.id) == str(pre_operatory.patient_id)

    if user.role == GoKlinikUser.RoleChoices.SUPER_ADMIN:
        return True

    if user.role in {
        GoKlinikUser.RoleChoices.CLINIC_MASTER,
        GoKlinikUser.RoleChoices.SURGEON,
        GoKlinikUser.RoleChoices.NURSE,
        GoKlinikUser.RoleChoices.SECRETARY,
    }:
        return str(user.tenant_id or "") == str(pre_operatory.tenant_id or "")

    return False


def _delete_storage_file_from_url(file_url: str | None) -> None:
    value = (file_url or "").strip()
    if not value:
        return

    path = urlsplit(value).path or value
    marker = "/pre_operatory/"
    index = path.find(marker)
    if index < 0:
        marker = "pre_operatory/"
        index = path.find(marker)
    if index < 0:
        return

    relative_path = path[index + 1 :] if path[index] == "/" else path[index:]
    if not relative_path:
        return

    try:
        default_storage.delete(relative_path)
    except Exception:
        # Silently ignore storage deletion errors because the DB reference
        # still needs to be removed for UX consistency.
        pass


class PreOperatoryCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)
        if not user.tenant_id:
            return Response(
                {"detail": "Patient tenant not found."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        active_record = _active_pre_operatory_for_patient(user)
        if active_record:
            return Response(
                {"detail": "Pre-operatory already exists for this patient."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = PreOperatoryWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        photos = list(request.FILES.getlist("photos"))
        documents = list(request.FILES.getlist("documents"))

        with transaction.atomic():
            pre_operatory = PreOperatory.objects.create(
                patient_id=user.id,
                tenant_id=user.tenant_id,
                allergies=data.get("allergies", ""),
                medications=data.get("medications", ""),
                previous_surgeries=data.get("previous_surgeries", ""),
                diseases=data.get("diseases", ""),
                smoking=data.get("smoking", False),
                alcohol=data.get("alcohol", False),
                height=data.get("height"),
                weight=data.get("weight"),
                status=PreOperatory.StatusChoices.PENDING,
            )

            for upload in photos:
                file_url = _save_uploaded_file(
                    request=request,
                    upload=upload,
                    folder=f"pre_operatory/{user.id}/{pre_operatory.id}/photos",
                )
                PreOperatoryFile.objects.create(
                    pre_operatory=pre_operatory,
                    file_url=file_url,
                    type=PreOperatoryFile.FileTypeChoices.PHOTO,
                )

            for upload in documents:
                file_url = _save_uploaded_file(
                    request=request,
                    upload=upload,
                    folder=f"pre_operatory/{user.id}/{pre_operatory.id}/documents",
                )
                PreOperatoryFile.objects.create(
                    pre_operatory=pre_operatory,
                    file_url=file_url,
                    type=PreOperatoryFile.FileTypeChoices.DOCUMENT,
                )

        pre_operatory = PreOperatory.objects.prefetch_related("files").get(id=pre_operatory.id)
        return Response(
            PreOperatorySerializer(
                pre_operatory,
                context={"request": request},
            ).data,
            status=status.HTTP_201_CREATED,
        )


class PreOperatoryMeAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        pre_operatory = (
            PreOperatory.objects.filter(patient_id=user.id)
            .prefetch_related("files")
            .order_by("-updated_at")
            .first()
        )
        if not pre_operatory:
            return Response(
                {"detail": "Pre-operatory not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(
            PreOperatorySerializer(
                pre_operatory,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )


class PreOperatoryDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, pre_operatory_id):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        pre_operatory = (
            PreOperatory.objects.filter(
                id=pre_operatory_id,
                patient_id=user.id,
            )
            .prefetch_related("files")
            .first()
        )
        if not pre_operatory:
            return Response(
                {"detail": "Pre-operatory not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        serializer = PreOperatoryWriteSerializer(
            pre_operatory,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        photos = list(request.FILES.getlist("photos"))
        documents = list(request.FILES.getlist("documents"))

        with transaction.atomic():
            for field_name in (
                "allergies",
                "medications",
                "previous_surgeries",
                "diseases",
                "smoking",
                "alcohol",
                "height",
                "weight",
            ):
                if field_name in data:
                    setattr(pre_operatory, field_name, data[field_name])
            pre_operatory.save()

            for upload in photos:
                file_url = _save_uploaded_file(
                    request=request,
                    upload=upload,
                    folder=f"pre_operatory/{user.id}/{pre_operatory.id}/photos",
                )
                PreOperatoryFile.objects.create(
                    pre_operatory=pre_operatory,
                    file_url=file_url,
                    type=PreOperatoryFile.FileTypeChoices.PHOTO,
                )

            for upload in documents:
                file_url = _save_uploaded_file(
                    request=request,
                    upload=upload,
                    folder=f"pre_operatory/{user.id}/{pre_operatory.id}/documents",
                )
                PreOperatoryFile.objects.create(
                    pre_operatory=pre_operatory,
                    file_url=file_url,
                    type=PreOperatoryFile.FileTypeChoices.DOCUMENT,
                )

        pre_operatory = PreOperatory.objects.prefetch_related("files").get(id=pre_operatory.id)
        return Response(
            PreOperatorySerializer(
                pre_operatory,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )


class PreOperatoryPatientAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, patient_id):
        patient = GoKlinikUser.objects.filter(
            id=patient_id,
            role=GoKlinikUser.RoleChoices.PATIENT,
        ).only("id", "tenant_id").first()
        if not patient:
            return Response(
                {"detail": "Patient not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not _can_staff_view_patient_pre_operatory(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        pre_operatory = (
            PreOperatory.objects.filter(patient_id=patient.id)
            .prefetch_related("files")
            .order_by("-updated_at")
            .first()
        )
        if not pre_operatory:
            return Response(
                {"detail": "Pre-operatory not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(
            PreOperatorySerializer(
                pre_operatory,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )


class PreOperatoryFileDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, file_id):
        file_row = (
            PreOperatoryFile.objects.select_related("pre_operatory")
            .filter(id=file_id)
            .first()
        )
        if not file_row:
            return Response(
                {"detail": "File not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not _can_manage_pre_operatory_file(request.user, file_row.pre_operatory):
            return Response(status=status.HTTP_403_FORBIDDEN)

        _delete_storage_file_from_url(file_row.file_url)
        file_row.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
