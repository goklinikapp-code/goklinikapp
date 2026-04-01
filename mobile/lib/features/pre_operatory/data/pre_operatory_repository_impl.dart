import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/pre_operatory_models.dart';
import '../domain/pre_operatory_repository.dart';

class PreOperatoryRepositoryImpl implements PreOperatoryRepository {
  PreOperatoryRepositoryImpl(this._dio);

  final Dio _dio;

  FormData _buildFormData(PreOperatoryUpsertPayload payload) {
    final formData = FormData.fromMap({
      'allergies': payload.allergies,
      'medications': payload.medications,
      'previous_surgeries': payload.previousSurgeries,
      'diseases': payload.diseases,
      'smoking': payload.smoking,
      'alcohol': payload.alcohol,
      'height': payload.height,
      'weight': payload.weight,
    });

    return formData;
  }

  Future<void> _appendFiles({
    required FormData formData,
    required String key,
    required List<String> filePaths,
  }) async {
    for (final path in filePaths) {
      if (path.trim().isEmpty) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      formData.files.add(
        MapEntry(
          key,
          await MultipartFile.fromFile(
            file.path,
            filename: file.uri.pathSegments.isEmpty
                ? file.path.split('/').last
                : file.uri.pathSegments.last,
          ),
        ),
      );
    }
  }

  @override
  Future<PreOperatoryRecord?> getMyPreOperatory() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.preOperatoryMe);
      return PreOperatoryRecord.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<PreOperatoryRecord> createPreOperatory(
    PreOperatoryUpsertPayload payload,
  ) async {
    final formData = _buildFormData(payload);
    await _appendFiles(
      formData: formData,
      key: 'photos',
      filePaths: payload.photoPaths,
    );
    await _appendFiles(
      formData: formData,
      key: 'documents',
      filePaths: payload.documentPaths,
    );

    final response = await _dio.post<dynamic>(
      ApiEndpoints.preOperatory,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return PreOperatoryRecord.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PreOperatoryRecord> updatePreOperatory(
    String preOperatoryId,
    PreOperatoryUpsertPayload payload,
  ) async {
    final formData = _buildFormData(payload);
    await _appendFiles(
      formData: formData,
      key: 'photos',
      filePaths: payload.photoPaths,
    );
    await _appendFiles(
      formData: formData,
      key: 'documents',
      filePaths: payload.documentPaths,
    );

    final response = await _dio.put<dynamic>(
      ApiEndpoints.preOperatoryDetail(preOperatoryId),
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return PreOperatoryRecord.fromJson(response.data as Map<String, dynamic>);
  }
}

final preOperatoryRepositoryProvider = Provider<PreOperatoryRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PreOperatoryRepositoryImpl(dio);
});
