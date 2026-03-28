import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/medical_records_repository_impl.dart';
import '../domain/medical_record_models.dart';

final myMedicalRecordProvider = FutureProvider<MedicalRecordSummary>((ref) {
  return ref.read(medicalRecordsRepositoryProvider).getMyRecord();
});

final medicalDocumentsProvider =
    FutureProvider.family<List<MedicalDocumentItem>, String>((ref, patientId) {
  return ref.read(medicalRecordsRepositoryProvider).getDocuments(patientId);
});
