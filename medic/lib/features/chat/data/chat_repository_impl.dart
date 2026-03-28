import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/chat_models.dart';
import '../domain/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<DoctorInboxMessage>> getInboxMessages() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.postOpUrgentRequests);
    final list = (response.data as List<dynamic>? ?? const []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(DoctorInboxMessage.fromJson)
        .toList();
  }

  @override
  Future<DoctorInboxMessage> replyToMessage({
    required String requestId,
    required String answer,
  }) async {
    final response = await _dio.put<dynamic>(
      ApiEndpoints.postOpUrgentRequestReply(requestId),
      data: {'answer': answer},
    );
    return DoctorInboxMessage.fromJson(response.data as Map<String, dynamic>);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ChatRepositoryImpl(dio);
});
