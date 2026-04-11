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
  Future<List<AppointmentItem>> getAppointments() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.appointments);
    final data = response.data;
    final list =
        (data is Map ? data['results'] : data) as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AppointmentItem.fromJson)
        .toList();
  }

  @override
  Future<List<AppointmentProfessional>> getAvailableProfessionals() async {
    final response = await _dio
        .get<dynamic>(ApiEndpoints.appointmentsAvailableProfessionals);
    final data = response.data;
    final list =
        (data is Map ? data['results'] : data) as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AppointmentProfessional.fromJson)
        .toList();
  }

  @override
  Future<AvailableSlotsResponse> getAvailableSlots({
    required String professionalId,
    required String date,
    String? specialtyId,
    String? appointmentId,
  }) async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.appointmentsAvailableSlots,
      queryParameters: {
        'professional_id': professionalId,
        'date': date,
        if (specialtyId != null && specialtyId.isNotEmpty)
          'specialty_id': specialtyId,
        if (appointmentId != null && appointmentId.isNotEmpty)
          'appointment_id': appointmentId,
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
    String? clinicLocation,
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
        if (clinicLocation != null && clinicLocation.isNotEmpty)
          'clinic_location': clinicLocation,
        'appointment_date': appointmentDate,
        'appointment_time': appointmentTime,
        'appointment_type': appointmentType,
        'notes': notes,
      },
    );
    return AppointmentItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
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
  }) async {
    final response = await _dio.patch<dynamic>(
      ApiEndpoints.appointmentDetail(appointmentId),
      data: {
        'patient': patientId,
        'professional': professionalId,
        if (specialtyId != null && specialtyId.isNotEmpty)
          'specialty': specialtyId,
        if (clinicLocation != null && clinicLocation.isNotEmpty)
          'clinic_location': clinicLocation,
        'appointment_date': appointmentDate,
        'appointment_time': appointmentTime,
        'appointment_type': appointmentType,
        'notes': notes,
      },
    );
    return AppointmentItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AppointmentItem> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    String? cancellationReason,
  }) async {
    final response = await _dio.put<dynamic>(
      ApiEndpoints.appointmentDetail(appointmentId),
      data: {
        'status': status,
        if (cancellationReason != null && cancellationReason.trim().isNotEmpty)
          'cancellation_reason': cancellationReason.trim(),
      },
    );
    return AppointmentItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> cancelAppointment({
    required String appointmentId,
    required String reason,
  }) async {
    await _dio.delete<dynamic>(
      ApiEndpoints.appointmentDetail(appointmentId),
      data: {
        'reason': reason,
      },
    );
  }
}

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AppointmentsRepositoryImpl(dio);
});
