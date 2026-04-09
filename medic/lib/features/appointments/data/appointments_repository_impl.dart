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
    final queryParameters =
        (professionalId != null && professionalId.isNotEmpty)
            ? {
                'professional': professionalId,
                'professional_id': professionalId,
              }
            : null;

    final collected = <Map<String, dynamic>>[];

    Response<dynamic> response = await _dio.get<dynamic>(
      ApiEndpoints.appointments,
      queryParameters: queryParameters,
    );

    dynamic data = response.data;
    if (data is List<dynamic>) {
      collected.addAll(data.whereType<Map<String, dynamic>>());
    } else if (data is Map) {
      final results = data['results'];
      if (results is List<dynamic>) {
        collected.addAll(results.whereType<Map<String, dynamic>>());
      }

      var next = (data['next'] ?? '').toString().trim();
      var guard = 0;
      while (next.isNotEmpty && guard < 20) {
        final nextResponse = await _dio.get<dynamic>(next);
        final nextData = nextResponse.data;
        if (nextData is! Map) break;

        final nextResults = nextData['results'];
        if (nextResults is List<dynamic>) {
          collected.addAll(nextResults.whereType<Map<String, dynamic>>());
        }

        next = (nextData['next'] ?? '').toString().trim();
        guard += 1;
      }
    }

    final parsed = collected.map(AppointmentItem.fromJson).toList();
    if (professionalId == null || professionalId.isEmpty) {
      return parsed;
    }

    // Defensive client-side guard to avoid cross-professional leakage when
    // backend caches/proxies return broader datasets.
    return parsed
        .where((item) => item.professionalId == professionalId)
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

  @override
  Future<ProfessionalAvailabilityResponse> getAvailabilityRules({
    String? professionalId,
  }) async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.appointmentsAvailabilityRules,
      queryParameters: (professionalId != null && professionalId.isNotEmpty)
          ? {'professional_id': professionalId}
          : null,
    );
    return ProfessionalAvailabilityResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<ProfessionalAvailabilityResponse> updateAvailabilityRules({
    String? professionalId,
    required List<ProfessionalAvailabilityRule> rules,
  }) async {
    final response = await _dio.put<dynamic>(
      ApiEndpoints.appointmentsAvailabilityRules,
      data: {
        if (professionalId != null && professionalId.isNotEmpty)
          'professional_id': professionalId,
        'rules': rules.map((item) => item.toJson()).toList(),
      },
    );
    return ProfessionalAvailabilityResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<List<BlockedPeriodItem>> getBlockedPeriods({
    String? professionalId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.appointmentsBlockedPeriods,
      queryParameters: {
        if (professionalId != null && professionalId.isNotEmpty)
          'professional_id': professionalId,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      },
    );
    final data = response.data;
    final rawList =
        (data is Map ? data['results'] : data) as List<dynamic>? ?? const [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(BlockedPeriodItem.fromJson)
        .toList();
  }

  @override
  Future<BlockedPeriodItem> createBlockedPeriod({
    String? professionalId,
    required String startDateTime,
    required String endDateTime,
    required String reason,
  }) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.appointmentsBlockedPeriods,
      data: {
        if (professionalId != null && professionalId.isNotEmpty)
          'professional_id': professionalId,
        'start_datetime': startDateTime,
        'end_datetime': endDateTime,
        'reason': reason,
      },
    );
    return BlockedPeriodItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteBlockedPeriod({required String blockedPeriodId}) async {
    await _dio.delete<dynamic>(
      ApiEndpoints.appointmentsBlockedPeriods,
      data: {'id': blockedPeriodId},
    );
  }
}

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AppointmentsRepositoryImpl(dio);
});
