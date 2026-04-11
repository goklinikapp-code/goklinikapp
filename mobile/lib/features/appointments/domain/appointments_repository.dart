import 'appointment_models.dart';

abstract class AppointmentsRepository {
  Future<List<AppointmentItem>> getAppointments();
  Future<List<AppointmentProfessional>> getAvailableProfessionals();
  Future<AvailableSlotsResponse> getAvailableSlots({
    required String professionalId,
    required String date,
    String? specialtyId,
    String? appointmentId,
  });

  Future<AppointmentItem> createAppointment({
    required String patientId,
    required String professionalId,
    String? specialtyId,
    String? clinicLocation,
    required String appointmentDate,
    required String appointmentTime,
    required String appointmentType,
    required String notes,
  });

  Future<AppointmentItem> updateAppointment({
    required String appointmentId,
    required String patientId,
    required String professionalId,
    String? specialtyId,
    String? clinicLocation,
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

  Future<void> cancelAppointment({
    required String appointmentId,
    required String reason,
  });
}
