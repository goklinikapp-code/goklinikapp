import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/patients_repository_impl.dart';
import '../domain/patient_models.dart';

final myPatientsProvider = FutureProvider<List<MedicPatient>>((ref) async {
  final session = ref.watch(authControllerProvider).session;
  final professionalId =
      session?.user.role == 'surgeon' ? session?.user.id : null;
  return ref
      .read(patientsRepositoryProvider)
      .getMyPatients(professionalId: professionalId);
});

final patientDetailProvider =
    FutureProvider.family<MedicPatient, String>((ref, patientId) async {
  return ref.read(patientsRepositoryProvider).getPatientDetail(patientId);
});

final patientHistoryProvider =
    FutureProvider.family<List<PatientTimelineItem>, String>(
        (ref, patientId) async {
  return ref.read(patientsRepositoryProvider).getPatientHistory(patientId);
});

final patientDocumentsProvider =
    FutureProvider.family<List<MedicalDocumentItem>, String>(
        (ref, patientId) async {
  return ref.read(patientsRepositoryProvider).getPatientDocuments(patientId);
});

final patientProntuarioMedicationsProvider =
    FutureProvider.family<List<ProntuarioMedicationItem>, String>(
        (ref, patientId) async {
  return ref
      .read(patientsRepositoryProvider)
      .getPatientProntuarioMedications(patientId);
});

final patientProntuarioProceduresProvider =
    FutureProvider.family<List<ProntuarioProcedureItem>, String>(
        (ref, patientId) async {
  return ref
      .read(patientsRepositoryProvider)
      .getPatientProntuarioProcedures(patientId);
});

final patientProntuarioDocumentsProvider =
    FutureProvider.family<List<ProntuarioDocumentItem>, String>(
        (ref, patientId) async {
  return ref
      .read(patientsRepositoryProvider)
      .getPatientProntuarioDocuments(patientId);
});

final patientJourneyProvider =
    FutureProvider.family<PostOpJourneySummary?, String>(
        (ref, patientId) async {
  return ref
      .read(patientsRepositoryProvider)
      .getActiveJourneyForPatient(patientId);
});

final journeyPhotosProvider =
    FutureProvider.family<List<EvolutionPhotoItem>, String>(
        (ref, journeyId) async {
  return ref.read(patientsRepositoryProvider).getJourneyPhotos(journeyId);
});
