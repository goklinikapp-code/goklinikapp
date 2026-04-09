import '../../../core/utils/api_media_url.dart';
import '../../../core/utils/text_normalizer.dart';

class DoctorInboxMessage {
  const DoctorInboxMessage({
    required this.id,
    required this.status,
    required this.question,
    required this.answer,
    required this.patientName,
    required this.patientEmail,
    required this.patientAvatarUrl,
    required this.assignedProfessionalName,
    required this.answeredByName,
    required this.createdAt,
    required this.updatedAt,
    this.answeredAt,
  });

  final String id;
  final String status;
  final String question;
  final String answer;
  final String patientName;
  final String patientEmail;
  final String patientAvatarUrl;
  final String assignedProfessionalName;
  final String answeredByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? answeredAt;

  bool get isAnswered => status == 'answered';
  bool get isOpen => status == 'open';

  String get statusLabel {
    switch (status) {
      case 'answered':
        return 'Respondida';
      case 'closed':
        return 'Fechada';
      case 'open':
      default:
        return 'Aguardando';
    }
  }

  factory DoctorInboxMessage.fromJson(Map<String, dynamic> json) {
    return DoctorInboxMessage(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'open').toString(),
      question: normalizeApiText(json['question']),
      answer: normalizeApiText(json['answer']),
      patientName: normalizeApiText(json['patient_name']),
      patientEmail: normalizeApiText(json['patient_email']),
      patientAvatarUrl: resolveApiMediaUrl(
        (json['patient_avatar_url'] ?? '').toString(),
      ),
      assignedProfessionalName:
          normalizeApiText(json['assigned_professional_name']),
      answeredByName: normalizeApiText(json['answered_by_name']),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
      answeredAt: DateTime.tryParse((json['answered_at'] ?? '').toString()),
    );
  }
}
