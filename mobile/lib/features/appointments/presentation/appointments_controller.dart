import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/appointments_repository_impl.dart';
import '../domain/appointment_models.dart';

class AppointmentsController
    extends StateNotifier<AsyncValue<List<AppointmentItem>>> {
  AppointmentsController(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => _ref.read(appointmentsRepositoryProvider).getAppointments());
  }

  Future<AppointmentItem?> createAppointment({
    required String professionalId,
    String? specialtyId,
    String? clinicLocation,
    required String date,
    required String time,
    required String notes,
    String appointmentType = 'first_visit',
  }) async {
    final session = _ref.read(authControllerProvider).session;
    if (session == null) return null;

    final item =
        await _ref.read(appointmentsRepositoryProvider).createAppointment(
              patientId: session.user.id,
              professionalId: professionalId,
              specialtyId: specialtyId,
              clinicLocation: clinicLocation,
              appointmentDate: date,
              appointmentTime: time,
              appointmentType: appointmentType,
              notes: notes,
            );
    await load();
    return item;
  }

  Future<AppointmentItem?> rescheduleAppointment({
    required String appointmentId,
    required String professionalId,
    String? specialtyId,
    String? clinicLocation,
    required String date,
    required String time,
    required String notes,
    String appointmentType = 'first_visit',
  }) async {
    final session = _ref.read(authControllerProvider).session;
    if (session == null) return null;

    final item =
        await _ref.read(appointmentsRepositoryProvider).updateAppointment(
              appointmentId: appointmentId,
              patientId: session.user.id,
              professionalId: professionalId,
              specialtyId: specialtyId,
              clinicLocation: clinicLocation,
              appointmentDate: date,
              appointmentTime: time,
              appointmentType: appointmentType,
              notes: notes,
            );
    await load();
    return item;
  }

  Future<void> cancelAppointment({
    required String appointmentId,
    required String reason,
  }) async {
    await _ref.read(appointmentsRepositoryProvider).cancelAppointment(
          appointmentId: appointmentId,
          reason: reason,
        );
    await load();
  }

  Future<List<String>> fetchSlots({
    required String professionalId,
    required String date,
    String? specialtyId,
    String? appointmentId,
  }) async {
    final response =
        await _ref.read(appointmentsRepositoryProvider).getAvailableSlots(
              professionalId: professionalId,
              date: date,
              specialtyId: specialtyId,
              appointmentId: appointmentId,
            );
    return response.slots;
  }

  Future<List<AppointmentProfessional>> fetchProfessionals() {
    return _ref
        .read(appointmentsRepositoryProvider)
        .getAvailableProfessionals();
  }
}

final appointmentsControllerProvider = StateNotifierProvider<
    AppointmentsController, AsyncValue<List<AppointmentItem>>>((ref) {
  return AppointmentsController(ref);
});
