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
}
