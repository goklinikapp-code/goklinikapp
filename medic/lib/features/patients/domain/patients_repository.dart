import 'dart:io';

import 'patient_models.dart';

abstract class PatientsRepository {
  Future<List<MedicPatient>> getMyPatients({String? professionalId});

  Future<MedicPatient> getPatientDetail(String patientId);

  Future<MedicPatient> updatePatientStatus({
    required String patientId,
    required MedicPatientStatus status,
    required String currentNotes,
  });

  Future<MedicPatient> updatePatientNotes({
    required String patientId,
    required String notes,
  });

  Future<List<PatientTimelineItem>> getPatientHistory(String patientId);

  Future<List<MedicalDocumentItem>> getPatientDocuments(String patientId);

  Future<List<ProntuarioMedicationItem>> getPatientProntuarioMedications(
      String patientId);
  Future<ProntuarioMedicationItem> createPatientProntuarioMedication({
    required String patientId,
    required Map<String, dynamic> payload,
  });
  Future<ProntuarioMedicationItem> updatePatientProntuarioMedication({
    required String patientId,
    required String medicationId,
    required Map<String, dynamic> payload,
  });
  Future<void> deactivatePatientProntuarioMedication({
    required String patientId,
    required String medicationId,
  });

  Future<List<ProntuarioProcedureItem>> getPatientProntuarioProcedures(
      String patientId);
  Future<ProntuarioProcedureItem> createPatientProntuarioProcedure({
    required String patientId,
    required Map<String, dynamic> payload,
    required List<File> images,
  });
  Future<ProntuarioProcedureItem> updatePatientProntuarioProcedure({
    required String patientId,
    required String procedureId,
    required Map<String, dynamic> payload,
    required List<File> images,
  });
  Future<void> deletePatientProntuarioProcedureImage({
    required String patientId,
    required String procedureId,
    required String imageId,
  });
  Future<void> deletePatientProntuarioProcedure({
    required String patientId,
    required String procedureId,
  });

  Future<List<ProntuarioDocumentItem>> getPatientProntuarioDocuments(
      String patientId);
  Future<ProntuarioDocumentItem> createPatientProntuarioDocument({
    required String patientId,
    required Map<String, dynamic> payload,
    File? file,
  });
  Future<ProntuarioDocumentItem> updatePatientProntuarioDocument({
    required String patientId,
    required String documentId,
    required Map<String, dynamic> payload,
    File? file,
  });
  Future<void> deletePatientProntuarioDocument({
    required String patientId,
    required String documentId,
  });

  Future<PostOpJourneySummary?> getActiveJourneyForPatient(String patientId);

  Future<List<EvolutionPhotoItem>> getJourneyPhotos(String journeyId);

  Future<EvolutionPhotoItem> uploadJourneyPhoto({
    required String journeyId,
    required int dayNumber,
    required File file,
  });
}
