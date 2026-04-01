import '../../../core/utils/api_media_url.dart';

class AppointmentItem {
  const AppointmentItem({
    required this.id,
    required this.patientId,
    required this.professionalId,
    required this.professionalName,
    required this.professionalRole,
    required this.professionalAvatarUrl,
    required this.clinicLocation,
    required this.specialtyId,
    required this.specialtyName,
    required this.status,
    required this.type,
    required this.date,
    required this.time,
    required this.notes,
  });

  final String id;
  final String patientId;
  final String professionalId;
  final String professionalName;
  final String professionalRole;
  final String professionalAvatarUrl;
  final String clinicLocation;
  final String specialtyId;
  final String specialtyName;
  final String status;
  final String type;
  final DateTime date;
  final String time;
  final String notes;

  DateTime get dateTime {
    final parts = time.split(':');
    if (parts.length < 2) return date;
    return DateTime(date.year, date.month, date.day,
        int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
  }

  factory AppointmentItem.fromJson(Map<String, dynamic> json) {
    final dateRaw =
        DateTime.tryParse((json['appointment_date'] ?? '').toString()) ??
            DateTime.now();
    return AppointmentItem(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patient'] ?? '').toString(),
      professionalId: (json['professional'] ?? '').toString(),
      professionalName: (json['professional_name'] ?? '').toString(),
      professionalRole: (json['professional_role'] ?? '').toString(),
      professionalAvatarUrl: resolveApiMediaUrl(
        (json['professional_avatar_url'] ?? '').toString(),
      ),
      clinicLocation: (json['clinic_location'] ?? '').toString(),
      specialtyId: (json['specialty'] ?? '').toString(),
      specialtyName: (json['specialty_name'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      type: (json['appointment_type'] ?? 'first_visit').toString(),
      date: dateRaw,
      time: (json['appointment_time'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
    );
  }
}

class AvailableSlotsResponse {
  const AvailableSlotsResponse({required this.slots});

  final List<String> slots;

  factory AvailableSlotsResponse.fromJson(Map<String, dynamic> json) {
    final slots = (json['slots'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    return AvailableSlotsResponse(slots: slots);
  }
}

class AppointmentProfessional {
  const AppointmentProfessional({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.isAssigned,
  });

  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final bool isAssigned;

  factory AppointmentProfessional.fromJson(Map<String, dynamic> json) {
    return AppointmentProfessional(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      avatarUrl: resolveApiMediaUrl((json['avatar_url'] ?? '').toString()),
      isAssigned: (json['is_assigned'] ?? false) == true,
    );
  }
}
