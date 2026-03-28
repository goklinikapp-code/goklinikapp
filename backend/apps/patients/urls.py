from django.urls import path
from rest_framework.routers import DefaultRouter

from apps.medical_records.views import (
    PatientDocumentDetailAPIView,
    PatientDocumentListCreateAPIView,
    PatientMedicationDetailAPIView,
    PatientMedicationListCreateAPIView,
    PatientProcedureImageDetailAPIView,
    PatientProcedureDetailAPIView,
    PatientProcedureListCreateAPIView,
)

from .views import PatientViewSet

router = DefaultRouter()
router.register(r"", PatientViewSet, basename="patients")

urlpatterns = [
    *router.urls,
    path("<uuid:patient_id>/medications/", PatientMedicationListCreateAPIView.as_view(), name="patients-medications"),
    path(
        "<uuid:patient_id>/medications/<uuid:medication_id>/",
        PatientMedicationDetailAPIView.as_view(),
        name="patients-medications-detail",
    ),
    path("<uuid:patient_id>/procedures/", PatientProcedureListCreateAPIView.as_view(), name="patients-procedures"),
    path(
        "<uuid:patient_id>/procedures/<uuid:procedure_id>/",
        PatientProcedureDetailAPIView.as_view(),
        name="patients-procedures-detail",
    ),
    path(
        "<uuid:patient_id>/procedures/<uuid:procedure_id>/images/<uuid:image_id>/",
        PatientProcedureImageDetailAPIView.as_view(),
        name="patients-procedures-images-detail",
    ),
    path("<uuid:patient_id>/documents/", PatientDocumentListCreateAPIView.as_view(), name="patients-documents"),
    path(
        "<uuid:patient_id>/documents/<uuid:document_id>/",
        PatientDocumentDetailAPIView.as_view(),
        name="patients-documents-detail",
    ),
]
