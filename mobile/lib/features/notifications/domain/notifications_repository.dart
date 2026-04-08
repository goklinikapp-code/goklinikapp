import 'notification_models.dart';

abstract class NotificationsRepository {
  Future<List<GKNotification>> getNotifications();
  Future<int> getUnreadCount();
  Future<void> registerToken({required String token, required String platform});
  Future<void> markAsRead(String id);
  Future<int> markAllAsRead();
  Future<int> clearAll();
}
