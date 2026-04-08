import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notifications_repository_impl.dart';
import '../domain/notification_models.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.loading = false,
    this.error,
  });

  final List<GKNotification> items;
  final int unreadCount;
  final bool loading;
  final String? error;

  NotificationsState copyWith({
    List<GKNotification>? items,
    int? unreadCount,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._ref) : super(const NotificationsState()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final repo = _ref.read(notificationsRepositoryProvider);
      final items = await repo.getNotifications();
      final unread = await repo.getUnreadCount();
      state = state.copyWith(
          items: items, unreadCount: unread, loading: false, clearError: true);
    } catch (_) {
      state = state.copyWith(
          loading: false, error: 'Falha ao carregar notificações.');
    }
  }

  Future<void> markAsRead(String id) async {
    await _ref.read(notificationsRepositoryProvider).markAsRead(id);
    await load();
  }

  Future<void> markAllAsRead() async {
    await _ref.read(notificationsRepositoryProvider).markAllAsRead();
    await load();
  }

  Future<int> clearAll() async {
    final deletedCount =
        await _ref.read(notificationsRepositoryProvider).clearAll();
    state = state.copyWith(
      items: const [],
      unreadCount: 0,
      clearError: true,
    );
    return deletedCount;
  }
}

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  return NotificationsController(ref);
});
