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
      final response =
          await _dio.get<dynamic>(ApiEndpoints.postOperatoryMyJourney);
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
    final response = await _dio
        .put<dynamic>(ApiEndpoints.postOpCompleteChecklist(checklistId));
    return PostOpChecklistItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PostOpChecklistItem> updateChecklistItem({
    required String checklistId,
    required bool completed,
  }) async {
    final response = await _dio.put<dynamic>(
      ApiEndpoints.postOperatoryChecklist(checklistId),
      data: {'completed': completed},
    );
    return PostOpChecklistItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PostOperatoryCheckin> submitCheckin({
    required int painLevel,
    required bool hasFever,
    required String notes,
    String? journeyId,
  }) async {
    final payload = <String, dynamic>{
      'pain_level': painLevel,
      'has_fever': hasFever,
      'notes': notes,
    };
    if (journeyId != null && journeyId.isNotEmpty) {
      payload['journey_id'] = journeyId;
    }

    final response = await _dio.post<dynamic>(
      ApiEndpoints.postOperatoryCheckin,
      data: payload,
    );
    return PostOperatoryCheckin.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<EvolutionPhotoItem>> getJourneyPhotos(String journeyId) async {
    final response =
        await _dio.get<dynamic>(ApiEndpoints.postOpPhotosByJourney(journeyId));
    final list = response.data as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(EvolutionPhotoItem.fromJson)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> uploadPhoto({
    required String journeyId,
    int? dayNumber,
    required String filePath,
    bool isAnonymous = false,
  }) async {
    final file = File(filePath);
    final formData = FormData.fromMap({
      'journey_id': journeyId,
      if (dayNumber != null) 'day': dayNumber,
      'is_anonymous': isAnonymous,
      'image': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
      ),
    });

    final response = await _dio.post<dynamic>(
      ApiEndpoints.postOperatoryPhoto,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<CareCenterData> getCareCenter(String journeyId) async {
    final response =
        await _dio.get<dynamic>(ApiEndpoints.postOpCareCenter(journeyId));
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
  Future<UrgentMedicalRequest> sendUrgentRequest(
      {required String question}) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.postOpUrgentRequests,
      data: {'question': question},
    );
    return UrgentMedicalRequest.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<UrgentTicket> createUrgentTicket({
    required String message,
    String severity = 'high',
    String? imagePath,
  }) async {
    final payload = <String, dynamic>{
      'message': message,
      'severity': severity,
    };

    final trimmedPath = (imagePath ?? '').trim();
    if (trimmedPath.isNotEmpty) {
      payload['image'] = await MultipartFile.fromFile(
        trimmedPath,
        filename: File(trimmedPath).uri.pathSegments.last,
      );
    }

    final response = await _dio.post<dynamic>(
      ApiEndpoints.urgentTickets,
      data: FormData.fromMap(payload),
      options: Options(contentType: 'multipart/form-data'),
    );
    return UrgentTicket.fromJson(response.data as Map<String, dynamic>);
  }
}

final postOpRepositoryProvider = Provider<PostOpRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PostOpRepositoryImpl(dio);
});
