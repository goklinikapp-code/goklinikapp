from django.urls import path

from .views import (
    MedicalDocumentListCreateAPIView,
    MedicalRecordAccessLogAPIView,
    MyMedicalRecordAPIView,
    PatientDocumentDetailAPIView,
    PatientDocumentListCreateAPIView,
    PatientMedicationDetailAPIView,
    PatientMedicationListCreateAPIView,
    PatientMedicationsAPIView,
    PatientProcedureImageDetailAPIView,
    PatientProcedureDetailAPIView,
    PatientProcedureListCreateAPIView,
)

urlpatterns = [
    path("my-record/", MyMedicalRecordAPIView.as_view(), name="medical-records-my-record"),
    path("<uuid:patient_id>/documents/", MedicalDocumentListCreateAPIView.as_view(), name="medical-records-documents"),
    path("<uuid:patient_id>/access-log/", MedicalRecordAccessLogAPIView.as_view(), name="medical-records-access-log"),
    path("<uuid:patient_id>/medications/", PatientMedicationsAPIView.as_view(), name="medical-records-medications"),
    path(
        "<uuid:patient_id>/prontuario/medications/",
        PatientMedicationListCreateAPIView.as_view(),
        name="medical-records-prontuario-medications",
    ),
    path(
        "<uuid:patient_id>/prontuario/medications/<uuid:medication_id>/",
        PatientMedicationDetailAPIView.as_view(),
        name="medical-records-prontuario-medications-detail",
    ),
    path(
        "<uuid:patient_id>/prontuario/procedures/",
        PatientProcedureListCreateAPIView.as_view(),
        name="medical-records-prontuario-procedures",
    ),
    path(
        "<uuid:patient_id>/prontuario/procedures/<uuid:procedure_id>/",
        PatientProcedureDetailAPIView.as_view(),
        name="medical-records-prontuario-procedures-detail",
    ),
    path(
        "<uuid:patient_id>/prontuario/procedures/<uuid:procedure_id>/images/<uuid:image_id>/",
        PatientProcedureImageDetailAPIView.as_view(),
        name="medical-records-prontuario-procedures-images-detail",
    ),
    path(
        "<uuid:patient_id>/prontuario/documents/",
        PatientDocumentListCreateAPIView.as_view(),
        name="medical-records-prontuario-documents",
    ),
    path(
        "<uuid:patient_id>/prontuario/documents/<uuid:document_id>/",
        PatientDocumentDetailAPIView.as_view(),
        name="medical-records-prontuario-documents-detail",
    ),
]
