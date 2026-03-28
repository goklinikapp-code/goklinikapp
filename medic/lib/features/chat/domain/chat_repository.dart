import 'chat_models.dart';

abstract class ChatRepository {
  Future<List<DoctorInboxMessage>> getInboxMessages();

  Future<DoctorInboxMessage> replyToMessage({
    required String requestId,
    required String answer,
  });
}
