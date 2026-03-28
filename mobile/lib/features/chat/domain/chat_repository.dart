import 'chat_models.dart';

abstract class ChatRepository {
  Future<List<ChatRoom>> getRooms();
  Future<ChatRoom> createOrGetRoom({required String patientId, required String roomType});
  Future<List<ChatMessage>> getMessages(String roomId);
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String content,
    required String messageType,
  });
  Future<int> markRoomRead(String roomId);
  Future<List<ChatMessage>> getAiMessages();
  Future<List<ChatMessage>> sendAiMessage({required String content});
}
