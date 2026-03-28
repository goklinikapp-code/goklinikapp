import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/postop_models.dart';
import '../domain/postop_repository.dart';

class PostOpRepositoryImpl implements PostOpRepository {
  PostOpRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<PostOpJourney?> getMyJourney() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.postOpMyJourney);
      return PostOpJourney.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<PostOpChecklistItem> completeChecklistItem(String checklistId) async {
    final response = await _dio.put<dynamic>(ApiEndpoints.postOpCompleteChecklist(checklistId));
    return PostOpChecklistItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<EvolutionPhotoItem>> getJourneyPhotos(String journeyId) async {
    final response = await _dio.get<dynamic>(ApiEndpoints.postOpPhotosByJourney(journeyId));
    final list = response.data as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(EvolutionPhotoItem.fromJson)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> uploadPhoto({
    required String journeyId,
    required int dayNumber,
    required String filePath,
    bool isAnonymous = false,
  }) async {
    final file = File(filePath);
    final formData = FormData.fromMap({
      'journey_id': journeyId,
      'day_number': dayNumber,
      'is_anonymous': isAnonymous,
      'photo': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
    });

    final response = await _dio.post<dynamic>(
      ApiEndpoints.postOpPhotos,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<CareCenterData> getCareCenter(String journeyId) async {
    final response = await _dio.get<dynamic>(ApiEndpoints.postOpCareCenter(journeyId));
    return CareCenterData.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<UrgentMedicalRequest>> getUrgentRequests() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.postOpUrgentRequests);
    final list = response.data as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(UrgentMedicalRequest.fromJson)
        .toList();
  }

  @override
  Future<UrgentMedicalRequest> sendUrgentRequest({required String question}) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.postOpUrgentRequests,
      data: {'question': question},
    );
    return UrgentMedicalRequest.fromJson(response.data as Map<String, dynamic>);
  }
}

final postOpRepositoryProvider = Provider<PostOpRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PostOpRepositoryImpl(dio);
});
