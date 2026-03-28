import 'medical_record_models.dart';

abstract class MedicalRecordsRepository {
  Future<MedicalRecordSummary> getMyRecord();
  Future<List<MedicalDocumentItem>> getDocuments(String patientId);
}
