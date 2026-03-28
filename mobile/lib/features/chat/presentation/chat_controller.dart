import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/chat_repository_impl.dart';
import '../domain/chat_models.dart';

const aiChatRoomId = 'ai';

class ChatRoomsController extends StateNotifier<AsyncValue<List<ChatRoom>>> {
  ChatRoomsController(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _ref.read(chatRepositoryProvider).getRooms();
    });
  }

  Future<ChatRoom?> createOrGetRoom({String roomType = 'doctor_patient'}) async {
    final session = _ref.read(authControllerProvider).session;
    if (session == null) return null;

    final room = await _ref.read(chatRepositoryProvider).createOrGetRoom(
          patientId: session.user.id,
          roomType: roomType,
        );
    await load();
    return room;
  }
}

final chatRoomsProvider =
    StateNotifierProvider<ChatRoomsController, AsyncValue<List<ChatRoom>>>((ref) {
  return ChatRoomsController(ref);
});

class ChatMessagesController extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  ChatMessagesController(this._ref, this.roomId) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  final String roomId;
  bool get _isAiChat => roomId == aiChatRoomId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (_isAiChat) {
        return _ref.read(chatRepositoryProvider).getAiMessages();
      }
      return _ref.read(chatRepositoryProvider).getMessages(roomId);
    });
  }

  Future<void> sendText(String content) async {
    await send(content: content, messageType: 'text');
  }

  Future<void> send({
    required String content,
    String messageType = 'text',
  }) async {
    if (_isAiChat) {
      try {
        final messages =
            await _ref.read(chatRepositoryProvider).sendAiMessage(content: content);
        state = AsyncValue.data(messages);
      } catch (_) {
        // Even when provider call fails or times out, backend may have persisted
        // the user message already. Reload to keep the chat timeline consistent.
        await load();
        rethrow;
      }
      return;
    }

    await _ref.read(chatRepositoryProvider).sendMessage(
      roomId: roomId,
      content: content,
      messageType: messageType,
    );
    await load();
  }

  Future<void> markRead() async {
    if (_isAiChat) return;
    await _ref.read(chatRepositoryProvider).markRoomRead(roomId);
  }
}

final chatMessagesProvider = StateNotifierProvider.family<
    ChatMessagesController,
    AsyncValue<List<ChatMessage>>,
    String>((ref, roomId) {
  return ChatMessagesController(ref, roomId);
});
