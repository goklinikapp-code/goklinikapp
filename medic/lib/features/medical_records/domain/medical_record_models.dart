import '../../../core/utils/api_media_url.dart';

class MedicalDocumentItem {
  const MedicalDocumentItem({
    required this.id,
    required this.documentType,
    required this.title,
    required this.fileUrl,
    required this.uploadedBy,
    required this.createdAt,
    required this.isSigned,
    this.validUntil,
  });

  final String id;
  final String documentType;
  final String title;
  final String fileUrl;
  final String uploadedBy;
  final DateTime createdAt;
  final bool isSigned;
  final DateTime? validUntil;

  factory MedicalDocumentItem.fromJson(Map<String, dynamic> json) {
    return MedicalDocumentItem(
      id: (json['id'] ?? '').toString(),
      documentType: (json['document_type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      fileUrl: resolveApiMediaUrl((json['file_url'] ?? '').toString()),
      uploadedBy: (json['uploaded_by'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      isSigned: json['is_signed'] == true,
      validUntil: DateTime.tryParse((json['valid_until'] ?? '').toString()),
    );
  }
}

class ProcedureHistoryItem {
  const ProcedureHistoryItem({
    required this.id,
    required this.date,
    required this.time,
    required this.type,
    required this.professionalName,
    required this.specialtyName,
  });

  final String id;
  final String date;
  final String time;
  final String type;
  final String professionalName;
  final String specialtyName;

  factory ProcedureHistoryItem.fromJson(Map<String, dynamic> json) {
    return ProcedureHistoryItem(
      id: (json['id'] ?? '').toString(),
      date: (json['appointment_date'] ?? '').toString(),
      time: (json['appointment_time'] ?? '').toString(),
      type: (json['appointment_type'] ?? '').toString(),
      professionalName: (json['professional_name'] ?? '').toString(),
      specialtyName: (json['specialty_name'] ?? '').toString(),
    );
  }
}

class MedicalRecordSummary {
  const MedicalRecordSummary({
    required this.patientId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.allergies,
    required this.previousSurgeries,
    required this.currentMedications,
    required this.procedureHistory,
    required this.documents,
  });

  final String patientId;
  final String fullName;
  final String email;
  final String phone;
  final String dateOfBirth;
  final String allergies;
  final String previousSurgeries;
  final String currentMedications;
  final List<ProcedureHistoryItem> procedureHistory;
  final List<MedicalDocumentItem> documents;

  factory MedicalRecordSummary.fromJson(Map<String, dynamic> json) {
    final patient =
        (json['patient'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final docs = (json['documents'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MedicalDocumentItem.fromJson)
        .toList();
    final history = (json['procedure_history'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProcedureHistoryItem.fromJson)
        .toList();

    return MedicalRecordSummary(
      patientId: (patient['id'] ?? '').toString(),
      fullName: (patient['full_name'] ?? '').toString(),
      email: (patient['email'] ?? '').toString(),
      phone: (patient['phone'] ?? '').toString(),
      dateOfBirth: (patient['date_of_birth'] ?? '').toString(),
      allergies: (json['allergies'] ?? '').toString(),
      previousSurgeries: (json['previous_surgeries'] ?? '').toString(),
      currentMedications: (json['current_medications'] ?? '').toString(),
      procedureHistory: history,
      documents: docs,
    );
  }
}
