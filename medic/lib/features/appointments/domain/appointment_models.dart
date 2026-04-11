import '../../../core/utils/api_media_url.dart';

class AppointmentItem {
  const AppointmentItem({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientAvatarUrl,
    required this.professionalId,
    required this.professionalName,
    required this.professionalAvatarUrl,
    required this.specialtyId,
    required this.specialtyName,
    required this.clinicLocation,
    required this.status,
    required this.type,
    required this.date,
    required this.time,
    required this.durationMinutes,
    required this.notes,
    required this.cancellationReason,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String patientAvatarUrl;
  final String professionalId;
  final String professionalName;
  final String professionalAvatarUrl;
  final String specialtyId;
  final String specialtyName;
  final String clinicLocation;
  final String status;
  final String type;
  final DateTime date;
  final String time;
  final int? durationMinutes;
  final String notes;
  final String cancellationReason;

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
    final patientData = json['patient'];
    final professionalData = json['professional'];

    String readAvatar({
      required dynamic rootValue,
      required dynamic nestedValue,
      required dynamic nestedFallbackValue,
    }) {
      final fromRoot = (rootValue ?? '').toString().trim();
      if (fromRoot.isNotEmpty) {
        return resolveApiMediaUrl(fromRoot);
      }
      final fromNested = (nestedValue ?? '').toString().trim();
      if (fromNested.isNotEmpty) {
        return resolveApiMediaUrl(fromNested);
      }
      final fromNestedFallback = (nestedFallbackValue ?? '').toString().trim();
      if (fromNestedFallback.isNotEmpty) {
        return resolveApiMediaUrl(fromNestedFallback);
      }
      return '';
    }

    return AppointmentItem(
      id: (json['id'] ?? '').toString(),
      patientId: (patientData is Map
              ? (patientData['id'] ?? patientData['uuid'] ?? '')
              : patientData)
          .toString(),
      patientName: (json['patient_name'] ?? '').toString(),
      patientAvatarUrl: readAvatar(
        rootValue: json['patient_avatar_url'] ?? json['patient_avatar'],
        nestedValue: patientData is Map ? patientData['avatar_url'] : null,
        nestedFallbackValue: patientData is Map
            ? (patientData['avatar'] ?? patientData['photo'])
            : null,
      ),
      professionalId: (professionalData is Map
              ? (professionalData['id'] ?? professionalData['uuid'] ?? '')
              : professionalData)
          .toString(),
      professionalName: (json['professional_name'] ?? '').toString(),
      professionalAvatarUrl: readAvatar(
        rootValue:
            json['professional_avatar_url'] ?? json['professional_avatar'],
        nestedValue:
            professionalData is Map ? professionalData['avatar_url'] : null,
        nestedFallbackValue: professionalData is Map
            ? (professionalData['avatar'] ?? professionalData['photo'])
            : null,
      ),
      specialtyId: (json['specialty'] ?? '').toString(),
      specialtyName: (json['specialty_name'] ?? '').toString(),
      clinicLocation: (json['clinic_location'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      type: (json['appointment_type'] ?? 'first_visit').toString(),
      date: dateRaw,
      time: (json['appointment_time'] ?? '').toString(),
      durationMinutes:
          int.tryParse((json['duration_minutes'] ?? '').toString()),
      notes: (json['notes'] ?? '').toString(),
      cancellationReason: (json['cancellation_reason'] ?? '').toString(),
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

class ProfessionalAvailabilityRule {
  const ProfessionalAvailabilityRule({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isActive,
  });

  final String id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isActive;

  factory ProfessionalAvailabilityRule.fromJson(Map<String, dynamic> json) {
    return ProfessionalAvailabilityRule(
      id: (json['id'] ?? '').toString(),
      dayOfWeek: int.tryParse((json['day_of_week'] ?? 0).toString()) ?? 0,
      startTime: (json['start_time'] ?? '').toString(),
      endTime: (json['end_time'] ?? '').toString(),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'is_active': isActive,
    };
  }
}

class ProfessionalAvailabilityResponse {
  const ProfessionalAvailabilityResponse({
    required this.professionalId,
    required this.professionalName,
    required this.rules,
  });

  final String professionalId;
  final String professionalName;
  final List<ProfessionalAvailabilityRule> rules;

  factory ProfessionalAvailabilityResponse.fromJson(Map<String, dynamic> json) {
    final rawRules = (json['rules'] as List<dynamic>? ?? const []);
    return ProfessionalAvailabilityResponse(
      professionalId: (json['professional_id'] ?? '').toString(),
      professionalName: (json['professional_name'] ?? '').toString(),
      rules: rawRules
          .whereType<Map<String, dynamic>>()
          .map(ProfessionalAvailabilityRule.fromJson)
          .toList(),
    );
  }
}

class BlockedPeriodItem {
  const BlockedPeriodItem({
    required this.id,
    required this.professionalId,
    required this.professionalName,
    required this.startDateTime,
    required this.endDateTime,
    required this.reason,
  });

  final String id;
  final String professionalId;
  final String professionalName;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final String reason;

  factory BlockedPeriodItem.fromJson(Map<String, dynamic> json) {
    return BlockedPeriodItem(
      id: (json['id'] ?? '').toString(),
      professionalId: (json['professional'] ?? '').toString(),
      professionalName: (json['professional_name'] ?? '').toString(),
      startDateTime:
          DateTime.tryParse((json['start_datetime'] ?? '').toString()),
      endDateTime: DateTime.tryParse((json['end_datetime'] ?? '').toString()),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}
