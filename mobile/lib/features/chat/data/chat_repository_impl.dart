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
  Future<List<ChatRoom>> getRooms() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.chatRooms);
    final list = (response.data as List<dynamic>? ?? const []);
    return list.whereType<Map<String, dynamic>>().map(ChatRoom.fromJson).toList();
  }

  @override
  Future<ChatRoom> createOrGetRoom({required String patientId, required String roomType}) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.chatRooms,
      data: {'patient_id': patientId, 'room_type': roomType},
    );
    return ChatRoom.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<ChatMessage>> getMessages(String roomId) async {
    final response = await _dio.get<dynamic>(ApiEndpoints.chatRoomMessages(roomId));
    final data = response.data as Map<String, dynamic>;
    final list = (data['results'] as List<dynamic>? ?? const []);
    return list.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
  }

  @override
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String content,
    required String messageType,
  }) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.chatRoomMessages(roomId),
      data: {'content': content, 'message_type': messageType},
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<int> markRoomRead(String roomId) async {
    final response = await _dio.put<dynamic>(ApiEndpoints.chatRoomRead(roomId));
    final data = response.data as Map<String, dynamic>;
    return int.tryParse((data['marked_count'] ?? 0).toString()) ?? 0;
  }

  @override
  Future<List<ChatMessage>> getAiMessages() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.chatAiMessages);
    final list = (response.data as List<dynamic>? ?? const []);
    final messages = list
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromAiJson)
        .toList();
    return messages.reversed.toList(growable: false);
  }

  @override
  Future<List<ChatMessage>> sendAiMessage({required String content}) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.chatAiMessages,
      data: {'content': content},
      options: Options(
        // AI responses can take longer than regular API endpoints.
        receiveTimeout: const Duration(seconds: 35),
        sendTimeout: const Duration(seconds: 25),
      ),
    );
    final data = response.data as Map<String, dynamic>;
    final list = (data['messages'] as List<dynamic>? ?? const []);
    final messages = list
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromAiJson)
        .toList();
    return messages.reversed.toList(growable: false);
  }

  @override
  Future<bool> getAiTypingStatus() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.chatAiTypingStatus);
    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      return payload['is_typing'] == true;
    }
    return false;
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ChatRepositoryImpl(dio);
});
