import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/medical_record_models.dart';
import '../domain/medical_records_repository.dart';

class MedicalRecordsRepositoryImpl implements MedicalRecordsRepository {
  MedicalRecordsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<MedicalRecordSummary> getMyRecord() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.medicalRecordMyRecord);
    return MedicalRecordSummary.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<MedicalDocumentItem>> getDocuments(String patientId) async {
    final response = await _dio.get<dynamic>(ApiEndpoints.medicalRecordDocuments(patientId));
    final list = response.data as List<dynamic>? ?? const [];
    return list.whereType<Map<String, dynamic>>().map(MedicalDocumentItem.fromJson).toList();
  }
}

final medicalRecordsRepositoryProvider = Provider<MedicalRecordsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MedicalRecordsRepositoryImpl(dio);
});
