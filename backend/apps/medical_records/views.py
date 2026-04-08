from __future__ import annotations

import re

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from config.media_urls import absolute_media_url

from apps.appointments.models import Appointment
from apps.patients.models import Patient
from apps.users.models import GoKlinikUser
from services.storage_paths import build_storage_path
from services.supabase_storage import SupabaseStorageError, upload_file

from .audit import log_record_access
from .models import (
    MedicalDocument,
    MedicalRecordAccessLog,
    PatientDocument,
    PatientMedication,
    PatientProcedure,
    PatientProcedureImage,
)
from .serializers import (
    MedicalDocumentCreateSerializer,
    MedicalDocumentSerializer,
    MedicalRecordAccessLogSerializer,
    PatientDocumentSerializer,
    PatientDocumentWriteSerializer,
    PatientMedicationSerializer,
    PatientMedicationWriteSerializer,
    PatientProcedureSerializer,
    PatientProcedureWriteSerializer,
)

STAFF_VIEW_ROLES = {
    GoKlinikUser.RoleChoices.CLINIC_MASTER,
    GoKlinikUser.RoleChoices.SURGEON,
    GoKlinikUser.RoleChoices.NURSE,
    GoKlinikUser.RoleChoices.SECRETARY,
}
STAFF_UPLOAD_ROLES = {
    GoKlinikUser.RoleChoices.CLINIC_MASTER,
    GoKlinikUser.RoleChoices.SURGEON,
    GoKlinikUser.RoleChoices.NURSE,
    GoKlinikUser.RoleChoices.SECRETARY,
}


def _save_uploaded_file(*, upload, tenant_id, patient_id, segments: tuple[str, ...]) -> str:
    storage_path = build_storage_path(
        tenant_id,
        "patients",
        patient_id,
        "medical-records",
        *segments,
        upload=upload,
    )
    return upload_file(upload, storage_path)


def _extract_request_list(request, key: str) -> list[str]:
    if hasattr(request.data, "getlist"):
        values = [str(item).strip() for item in request.data.getlist(key)]
        values = [item for item in values if item]
        if values:
            return values
    raw = request.data.get(key)
    if isinstance(raw, list):
        return [str(item).strip() for item in raw if str(item).strip()]
    if isinstance(raw, str) and raw.strip():
        return [raw.strip()]
    return []


def _procedure_payload_without_files(request):
    payload = request.data.copy()
    if hasattr(payload, "pop"):
        payload.pop("images", None)
    return payload


def _get_patient(patient_id) -> Patient | None:
    return Patient.objects.filter(id=patient_id).first()


def _can_access_patient(user: GoKlinikUser, patient: Patient) -> bool:
    if user.role == GoKlinikUser.RoleChoices.PATIENT:
        return str(user.id) == str(patient.id)
    if user.role in STAFF_VIEW_ROLES:
        return str(user.tenant_id) == str(patient.tenant_id)
    return False


def _can_manage_patient(user: GoKlinikUser, patient: Patient) -> bool:
    if user.role not in STAFF_UPLOAD_ROLES:
        return False
    return str(user.tenant_id) == str(patient.tenant_id)


def _parse_medications(text: str) -> list[str]:
    chunks = re.split(r"[\n,;]+", text or "")
    return [item.strip() for item in chunks if item.strip()]


def _get_patient_or_404_or_forbidden(*, request, patient_id):
    patient = _get_patient(patient_id)
    if not patient:
        return None, Response({"detail": "Patient not found."}, status=status.HTTP_404_NOT_FOUND)
    if not _can_access_patient(request.user, patient):
        return None, Response(status=status.HTTP_403_FORBIDDEN)
    return patient, None


class MedicalDocumentListCreateAPIView(APIView):
    """
    Legacy endpoint preserved for compatibility.
    """

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, patient_id):
        patient = _get_patient(patient_id)
        if not patient:
            return Response({"detail": "Patient not found."}, status=status.HTTP_404_NOT_FOUND)

        if not _can_access_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.VIEW)
        queryset = MedicalDocument.objects.filter(patient=patient).select_related("uploaded_by")
        data = MedicalDocumentSerializer(
            queryset,
            many=True,
            context={"request": request},
        ).data
        return Response(data, status=status.HTTP_200_OK)

    def post(self, request, patient_id):
        patient = _get_patient(patient_id)
        if not patient:
            return Response({"detail": "Patient not found."}, status=status.HTTP_404_NOT_FOUND)

        if not _can_manage_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = MedicalDocumentCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = serializer.validated_data

        try:
            file_url = payload.get("file_url")
            if payload.get("file"):
                file_url = _save_uploaded_file(
                    upload=payload["file"],
                    tenant_id=patient.tenant_id,
                    patient_id=patient.id,
                    segments=("medical-documents",),
                )
            else:
                file_url = absolute_media_url(file_url, request=request)
        except SupabaseStorageError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        document = MedicalDocument.objects.create(
            patient=patient,
            tenant=patient.tenant,
            document_type=payload["document_type"],
            title=payload["title"],
            file_url=file_url,
            uploaded_by=request.user,
            is_signed=payload.get("is_signed", False),
            valid_until=payload.get("valid_until"),
        )
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.EDIT)
        return Response(
            MedicalDocumentSerializer(document, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class MedicalRecordAccessLogAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, patient_id):
        patient = _get_patient(patient_id)
        if not patient:
            return Response({"detail": "Patient not found."}, status=status.HTTP_404_NOT_FOUND)

        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)
        if str(user.tenant_id) != str(patient.tenant_id):
            return Response(status=status.HTTP_403_FORBIDDEN)

        logs = MedicalRecordAccessLog.objects.filter(patient=patient).select_related("accessed_by")
        return Response(
            MedicalRecordAccessLogSerializer(logs, many=True).data,
            status=status.HTTP_200_OK,
        )


class PatientMedicationListCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, patient_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error

        rows = PatientMedication.objects.filter(patient=patient).order_by(
            "-em_uso",
            "-data_inicio",
            "-criado_em",
        )
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.VIEW)
        return Response(
            PatientMedicationSerializer(rows, many=True).data,
            status=status.HTTP_200_OK,
        )

    def post(self, request, patient_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error

        if not _can_manage_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = PatientMedicationWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        medication = serializer.save(patient=patient, tenant=patient.tenant)
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.EDIT)
        return Response(
            PatientMedicationSerializer(medication).data,
            status=status.HTTP_201_CREATED,
        )


class PatientMedicationDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, patient_id, medication_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error
        if not _can_manage_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        medication = get_object_or_404(PatientMedication, id=medication_id, patient=patient)
        serializer = PatientMedicationWriteSerializer(medication, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        updated = serializer.save()
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.EDIT)
        return Response(
            PatientMedicationSerializer(updated).data,
            status=status.HTTP_200_OK,
        )

    def delete(self, request, patient_id, medication_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error
        if not _can_manage_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        medication = get_object_or_404(PatientMedication, id=medication_id, patient=patient)
        medication.em_uso = False
        if not medication.data_fim:
            medication.data_fim = timezone.localdate()
        medication.save(update_fields=["em_uso", "data_fim", "atualizado_em"])
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.EDIT)
        return Response(status=status.HTTP_204_NO_CONTENT)


class PatientProcedureListCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, patient_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error

        queryset = PatientProcedure.objects.filter(patient=patient).prefetch_related("images")
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.VIEW)
        return Response(
            PatientProcedureSerializer(
                queryset,
                many=True,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )

    def post(self, request, patient_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error
        if not _can_manage_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = PatientProcedureWriteSerializer(data=_procedure_payload_without_files(request))
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        uploaded_images = list(request.FILES.getlist("images"))
        image_urls = data.get("image_urls", []) or _extract_request_list(request, "image_urls")

        try:
            with transaction.atomic():
                procedure = PatientProcedure.objects.create(
                    patient=patient,
                    tenant=patient.tenant,
                    nome_procedimento=data["nome_procedimento"],
                    descricao=data.get("descricao", ""),
                    data_procedimento=data["data_procedimento"],
                    profissional_responsavel=data.get("profissional_responsavel", ""),
                    observacoes=data.get("observacoes", ""),
                )

                for upload in uploaded_images:
                    image_url = _save_uploaded_file(
                        upload=upload,
                        tenant_id=patient.tenant_id,
                        patient_id=patient.id,
                        segments=("procedures", str(procedure.id), "images"),
                    )
                    PatientProcedureImage.objects.create(procedure=procedure, image_url=image_url)

                for image_url in image_urls:
                    PatientProcedureImage.objects.create(
                        procedure=procedure,
                        image_url=absolute_media_url(image_url, request=request),
                    )
        except SupabaseStorageError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.EDIT)
        procedure = PatientProcedure.objects.prefetch_related("images").get(id=procedure.id)
        return Response(
            PatientProcedureSerializer(
                procedure,
                context={"request": request},
            ).data,
            status=status.HTTP_201_CREATED,
        )


class PatientProcedureDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, patient_id, procedure_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error
        if not _can_manage_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        procedure = get_object_or_404(PatientProcedure, id=procedure_id, patient=patient)
        serializer = PatientProcedureWriteSerializer(
            procedure,
            data=_procedure_payload_without_files(request),
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        uploaded_images = list(request.FILES.getlist("images"))
        image_urls = data.get("image_urls", []) or _extract_request_list(request, "image_urls")

        try:
            with transaction.atomic():
                for attr in (
                    "nome_procedimento",
                    "descricao",
                    "data_procedimento",
                    "profissional_responsavel",
                    "observacoes",
                ):
                    if attr in data:
                        setattr(procedure, attr, data[attr])
                procedure.save()

                for upload in uploaded_images:
                    image_url = _save_uploaded_file(
                        upload=upload,
                        tenant_id=patient.tenant_id,
                        patient_id=patient.id,
                        segments=("procedures", str(procedure.id), "images"),
                    )
                    PatientProcedureImage.objects.create(procedure=procedure, image_url=image_url)

                for image_url in image_urls:
                    PatientProcedureImage.objects.create(
                        procedure=procedure,
                        image_url=absolute_media_url(image_url, request=request),
                    )
        except SupabaseStorageError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.EDIT)
        procedure = PatientProcedure.objects.prefetch_related("images").get(id=procedure.id)
        return Response(
            PatientProcedureSerializer(
                procedure,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )

    def delete(self, request, patient_id, procedure_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error
        if not _can_manage_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        procedure = get_object_or_404(PatientProcedure, id=procedure_id, patient=patient)
        procedure.delete()
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.EDIT)
        return Response(status=status.HTTP_204_NO_CONTENT)


class PatientProcedureImageDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, patient_id, procedure_id, image_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error
        if not _can_manage_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        procedure = get_object_or_404(PatientProcedure, id=procedure_id, patient=patient)
        image = get_object_or_404(PatientProcedureImage, id=image_id, procedure=procedure)
        image.delete()
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.EDIT)
        return Response(status=status.HTTP_204_NO_CONTENT)


class PatientDocumentListCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, patient_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error

        queryset = PatientDocument.objects.filter(patient=patient).select_related("uploaded_by")
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.VIEW)
        return Response(
            PatientDocumentSerializer(
                queryset,
                many=True,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )

    def post(self, request, patient_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error
        if not _can_manage_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = PatientDocumentWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = serializer.validated_data

        try:
            arquivo_url = payload.get("file_url")
            if payload.get("file"):
                arquivo_url = _save_uploaded_file(
                    upload=payload["file"],
                    tenant_id=patient.tenant_id,
                    patient_id=patient.id,
                    segments=("documents",),
                )
            arquivo_url = absolute_media_url(arquivo_url, request=request)
        except SupabaseStorageError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        document = PatientDocument.objects.create(
            patient=patient,
            tenant=patient.tenant,
            titulo=payload["titulo"],
            descricao=payload.get("descricao", ""),
            arquivo_url=arquivo_url,
            tipo_arquivo=payload["tipo_arquivo"],
            uploaded_by=request.user,
        )
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.EDIT)
        return Response(
            PatientDocumentSerializer(
                document,
                context={"request": request},
            ).data,
            status=status.HTTP_201_CREATED,
        )


class PatientDocumentDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, patient_id, document_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error
        if not _can_manage_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        document = get_object_or_404(PatientDocument, id=document_id, patient=patient)
        serializer = PatientDocumentWriteSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        payload = serializer.validated_data

        for field_name in ("titulo", "descricao", "tipo_arquivo"):
            if field_name in payload:
                setattr(document, field_name, payload[field_name])

        try:
            if payload.get("file"):
                document.arquivo_url = _save_uploaded_file(
                    upload=payload["file"],
                    tenant_id=patient.tenant_id,
                    patient_id=patient.id,
                    segments=("documents",),
                )
            elif payload.get("file_url"):
                document.arquivo_url = absolute_media_url(
                    payload["file_url"],
                    request=request,
                )
        except SupabaseStorageError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        document.save()
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.EDIT)
        return Response(
            PatientDocumentSerializer(
                document,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )

    def delete(self, request, patient_id, document_id):
        patient, error = _get_patient_or_404_or_forbidden(request=request, patient_id=patient_id)
        if error:
            return error
        if not _can_manage_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        document = get_object_or_404(PatientDocument, id=document_id, patient=patient)
        document.delete()
        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.EDIT)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MyMedicalRecordAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        patient = _get_patient(user.id)
        if not patient:
            return Response({"detail": "Patient not found."}, status=status.HTTP_404_NOT_FOUND)

        documents = (
            PatientDocument.objects.filter(patient=patient)
            .select_related("uploaded_by")
            .order_by("-criado_em")
        )
        procedures_qs = (
            PatientProcedure.objects.filter(patient=patient)
            .prefetch_related("images")
            .order_by("-data_procedimento", "-criado_em")
        )
        medications = (
            PatientMedication.objects.filter(patient=patient)
            .order_by("-em_uso", "-data_inicio", "-criado_em")
        )

        procedures = list(procedures_qs)
        procedure_history: list[dict] = []

        if procedures:
            procedure_history = [
                {
                    "id": str(item.id),
                    "nome_procedimento": item.nome_procedimento,
                    "descricao": item.descricao,
                    "data_procedimento": item.data_procedimento,
                    "profissional_responsavel": item.profissional_responsavel,
                    "observacoes": item.observacoes,
                    "images": [
                        {
                            "id": str(image.id),
                            "image_url": absolute_media_url(
                                image.image_url,
                                request=request,
                            ),
                            "criado_em": image.criado_em,
                        }
                        for image in item.images.all()
                    ],
                }
                for item in procedures
            ]
        else:
            # Backward-compatible fallback from appointments only if no custom procedure yet.
            completed_appointments = (
                Appointment.objects.filter(patient=patient, status=Appointment.StatusChoices.COMPLETED)
                .select_related("professional", "specialty")
                .order_by("-appointment_date", "-appointment_time")
            )
            for item in completed_appointments:
                procedure_history.append(
                    {
                        "id": str(item.id),
                        "nome_procedimento": (
                            item.specialty.specialty_name
                            if item.specialty
                            else item.appointment_type
                        ),
                        "descricao": item.notes or "",
                        "data_procedimento": item.appointment_date,
                        "profissional_responsavel": (
                            item.professional.full_name if item.professional else ""
                        ),
                        "observacoes": item.internal_notes or "",
                        "images": [],
                    }
                )

        latest_procedure = procedure_history[0] if procedure_history else None
        medication_items = PatientMedicationSerializer(medications, many=True).data
        current_medications = ", ".join(
            [
                med["nome_medicamento"]
                for med in medication_items
                if med.get("em_uso")
            ]
        )

        log_record_access(request, patient, MedicalRecordAccessLog.ActionChoices.VIEW)
        return Response(
            {
                "patient": {
                    "id": str(patient.id),
                    "full_name": patient.full_name,
                    "email": patient.email,
                    "phone": patient.phone,
                    "cpf": patient.cpf,
                    "avatar_url": absolute_media_url(
                        patient.avatar_url,
                        request=request,
                    ),
                    "date_of_birth": patient.date_of_birth,
                    "health_insurance": patient.health_insurance,
                },
                "allergies": patient.allergies,
                "previous_surgeries": patient.previous_surgeries,
                "current_medications": current_medications,
                "medications": medication_items,
                "latest_procedure": latest_procedure,
                "procedure_history": procedure_history,
                "documents": PatientDocumentSerializer(
                    documents,
                    many=True,
                    context={"request": request},
                ).data,
            },
            status=status.HTTP_200_OK,
        )


class PatientMedicationsAPIView(APIView):
    """
    Legacy meds endpoint used by older app flows.
    """

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, patient_id):
        patient = _get_patient(patient_id)
        if not patient:
            return Response({"detail": "Patient not found."}, status=status.HTTP_404_NOT_FOUND)

        if not _can_access_patient(request.user, patient):
            return Response(status=status.HTTP_403_FORBIDDEN)

        rows = PatientMedication.objects.filter(patient=patient).order_by("-em_uso", "-data_inicio")
        if rows.exists():
            medications = [row.nome_medicamento for row in rows]
        else:
            medications = _parse_medications(patient.current_medications)
        return Response(
            {
                "patient_id": str(patient.id),
                "medications": medications,
            },
            status=status.HTTP_200_OK,
        )
