import '../../../core/utils/api_media_url.dart';

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
      question: (json['question'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
      patientName: (json['patient_name'] ?? '').toString(),
      patientEmail: (json['patient_email'] ?? '').toString(),
      patientAvatarUrl: resolveApiMediaUrl(
        (json['patient_avatar_url'] ?? '').toString(),
      ),
      assignedProfessionalName:
          (json['assigned_professional_name'] ?? '').toString(),
      answeredByName: (json['answered_by_name'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
      answeredAt: DateTime.tryParse((json['answered_at'] ?? '').toString()),
    );
  }
}
