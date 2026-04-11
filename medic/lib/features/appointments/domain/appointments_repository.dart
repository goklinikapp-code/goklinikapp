import 'appointment_models.dart';

abstract class AppointmentsRepository {
  Future<List<AppointmentItem>> getAppointments({String? professionalId});
  Future<AvailableSlotsResponse> getAvailableSlots({
    required String professionalId,
    required String date,
    String? specialtyId,
  });

  Future<AppointmentItem> createAppointment({
    required String patientId,
    required String professionalId,
    String? specialtyId,
    required String appointmentDate,
    required String appointmentTime,
    required String appointmentType,
    required String notes,
  });

  Future<AppointmentItem> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    String? cancellationReason,
  });

  Future<ProfessionalAvailabilityResponse> getAvailabilityRules({
    String? professionalId,
  });

  Future<ProfessionalAvailabilityResponse> updateAvailabilityRules({
    String? professionalId,
    required List<ProfessionalAvailabilityRule> rules,
  });

  Future<List<BlockedPeriodItem>> getBlockedPeriods({
    String? professionalId,
    String? dateFrom,
    String? dateTo,
  });

  Future<BlockedPeriodItem> createBlockedPeriod({
    String? professionalId,
    required String startDateTime,
    required String endDateTime,
    required String reason,
  });

  Future<void> deleteBlockedPeriod({required String blockedPeriodId});
}
