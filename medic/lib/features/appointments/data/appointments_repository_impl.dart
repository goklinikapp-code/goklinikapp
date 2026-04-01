import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/appointment_models.dart';
import '../domain/appointments_repository.dart';

class AppointmentsRepositoryImpl implements AppointmentsRepository {
  AppointmentsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<AppointmentItem>> getAppointments(
      {String? professionalId}) async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.appointments,
      queryParameters: (professionalId != null && professionalId.isNotEmpty)
          ? {
              'professional': professionalId,
              'professional_id': professionalId,
            }
          : null,
    );
    final data = response.data;
    final list =
        (data is Map ? data['results'] : data) as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AppointmentItem.fromJson)
        .toList();
  }

  @override
  Future<AvailableSlotsResponse> getAvailableSlots({
    required String professionalId,
    required String date,
    String? specialtyId,
  }) async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.appointmentsAvailableSlots,
      queryParameters: {
        'professional_id': professionalId,
        'date': date,
        if (specialtyId != null && specialtyId.isNotEmpty)
          'specialty_id': specialtyId,
      },
    );
    return AvailableSlotsResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  @override
  Future<AppointmentItem> createAppointment({
    required String patientId,
    required String professionalId,
    String? specialtyId,
    required String appointmentDate,
    required String appointmentTime,
    required String appointmentType,
    required String notes,
  }) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.appointments,
      data: {
        'patient': patientId,
        'professional': professionalId,
        if (specialtyId != null && specialtyId.isNotEmpty)
          'specialty': specialtyId,
        'appointment_date': appointmentDate,
        'appointment_time': appointmentTime,
        'appointment_type': appointmentType,
        'notes': notes,
      },
    );
    return AppointmentItem.fromJson(response.data as Map<String, dynamic>);
  }
}

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AppointmentsRepositoryImpl(dio);
});
