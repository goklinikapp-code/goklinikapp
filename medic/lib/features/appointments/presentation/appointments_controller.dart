import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/appointments_repository_impl.dart';
import '../domain/appointment_models.dart';

class AppointmentsController
    extends StateNotifier<AsyncValue<List<AppointmentItem>>> {
  AppointmentsController(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen<AuthViewState>(
      authControllerProvider,
      (previous, next) {
        final previousUserId = previous?.session?.user.id ?? '';
        final nextUserId = next.session?.user.id ?? '';
        if (previousUserId == nextUserId) return;

        if (next.session == null) {
          state = const AsyncValue.data(<AppointmentItem>[]);
          return;
        }
        load();
      },
    );
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    final session = _ref.read(authControllerProvider).session;
    final professionalId =
        session?.user.role == 'surgeon' ? session?.user.id.trim() : null;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async {
        final appointments = await _ref
            .read(appointmentsRepositoryProvider)
            .getAppointments(professionalId: professionalId);
        if (professionalId == null || professionalId.isEmpty) {
          return appointments;
        }
        return appointments
            .where((item) => item.professionalId == professionalId)
            .toList();
      },
    );
  }

  Future<AppointmentItem?> createAppointment({
    required String professionalId,
    String? specialtyId,
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
              appointmentDate: date,
              appointmentTime: time,
              appointmentType: appointmentType,
              notes: notes,
            );
    await load();
    return item;
  }

  Future<List<String>> fetchSlots({
    required String professionalId,
    required String date,
    String? specialtyId,
  }) async {
    final response =
        await _ref.read(appointmentsRepositoryProvider).getAvailableSlots(
              professionalId: professionalId,
              date: date,
              specialtyId: specialtyId,
            );
    return response.slots;
  }

  Future<AppointmentItem> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    String? cancellationReason,
  }) async {
    final updated =
        await _ref.read(appointmentsRepositoryProvider).updateAppointmentStatus(
              appointmentId: appointmentId,
              status: status,
              cancellationReason: cancellationReason,
            );
    await load();
    return updated;
  }
}

final appointmentsControllerProvider = StateNotifierProvider<
    AppointmentsController, AsyncValue<List<AppointmentItem>>>((ref) {
  return AppointmentsController(ref);
});
