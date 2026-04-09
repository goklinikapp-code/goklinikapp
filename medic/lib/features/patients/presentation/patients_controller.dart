import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/data/appointments_repository_impl.dart';
import '../../appointments/domain/appointment_models.dart';
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

final patientPreOperatoryProvider =
    FutureProvider.family<PatientPreOperatoryRecord?, String>(
        (ref, patientId) async {
  return ref.read(patientsRepositoryProvider).getPatientPreOperatory(patientId);
});

final myPreOperatoryRecordsProvider =
    FutureProvider.family<List<PatientPreOperatoryRecord>, PreOperatoryStatus?>(
        (ref, status) async {
  return ref
      .read(patientsRepositoryProvider)
      .getMyPreOperatoryRecords(status: status);
});

final myActiveAppointmentsProvider =
    FutureProvider<List<AppointmentItem>>((ref) async {
  final session = ref.watch(authControllerProvider).session;
  final surgeonId = session?.user.id;
  if (session?.user.role != 'surgeon' ||
      surgeonId == null ||
      surgeonId.isEmpty) {
    return const <AppointmentItem>[];
  }

  final appointments = await ref
      .read(appointmentsRepositoryProvider)
      .getAppointments(professionalId: surgeonId);
  const activeStatuses = {
    'pending',
    'confirmed',
    'in_progress',
  };

  return appointments
      .where((item) => item.professionalId == surgeonId)
      .where((item) => activeStatuses.contains(item.status))
      .toList();
});

final patientPostOperatoryProvider =
    FutureProvider.family<PatientPostOperatoryRecord?, String>(
        (ref, patientId) async {
  return ref
      .read(patientsRepositoryProvider)
      .getPatientPostOperatory(patientId);
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

class UrgentTicketsController
    extends StateNotifier<AsyncValue<List<UrgentTicketItem>>> {
  UrgentTicketsController(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = await AsyncValue.guard(
      () => _ref.read(patientsRepositoryProvider).getUrgentTickets(),
    );
  }

  Future<void> updateStatus({
    required String ticketId,
    required String status,
  }) async {
    await _ref.read(patientsRepositoryProvider).updateUrgentTicketStatus(
          ticketId: ticketId,
          status: status,
        );
    await load();
  }
}

final urgentTicketsProvider = StateNotifierProvider<UrgentTicketsController,
    AsyncValue<List<UrgentTicketItem>>>(
  (ref) => UrgentTicketsController(ref),
);
