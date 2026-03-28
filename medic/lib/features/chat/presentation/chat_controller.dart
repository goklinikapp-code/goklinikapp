import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository_impl.dart';
import '../domain/chat_models.dart';

class ChatInboxController
    extends StateNotifier<AsyncValue<List<DoctorInboxMessage>>> {
  ChatInboxController(this._ref) : super(const AsyncValue.loading()) {
    load(forceLoading: true);
  }

  final Ref _ref;

  Future<void> load({bool forceLoading = false}) async {
    final previous = state.valueOrNull;
    if (forceLoading || previous == null) {
      state = const AsyncValue.loading();
    }
    try {
      final list = await _ref.read(chatRepositoryProvider).getInboxMessages();
      state = AsyncValue.data(list);
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> reply({
    required String requestId,
    required String answer,
  }) async {
    await _ref.read(chatRepositoryProvider).replyToMessage(
          requestId: requestId,
          answer: answer,
        );
    await load();
  }
}

final chatInboxProvider = StateNotifierProvider<ChatInboxController,
    AsyncValue<List<DoctorInboxMessage>>>((ref) {
  return ChatInboxController(ref);
});
