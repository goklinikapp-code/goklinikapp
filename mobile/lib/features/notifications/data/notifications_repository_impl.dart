import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/notification_models.dart';
import '../domain/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<GKNotification>> getNotifications() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.notifications);
    final data = response.data;
    final results =
        (data is Map ? data['results'] : data) as List<dynamic>? ?? const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(GKNotification.fromJson)
        .toList();
  }

  @override
  Future<int> getUnreadCount() async {
    final response =
        await _dio.get<dynamic>(ApiEndpoints.notificationsUnreadCount);
    final data = response.data;
    if (data is! Map) return 0;
    return int.tryParse((data['unread_count'] ?? 0).toString()) ?? 0;
  }

  @override
  Future<void> registerToken(
      {required String token, required String platform}) async {
    await _dio.post<dynamic>(
      ApiEndpoints.notificationsRegisterToken,
      data: {'device_token': token, 'platform': platform},
    );
  }

  @override
  Future<void> markAsRead(String id) async {
    await _dio.put<dynamic>(ApiEndpoints.notificationsRead(id));
  }

  @override
  Future<int> markAllAsRead() async {
    final response = await _dio.put<dynamic>(ApiEndpoints.notificationsReadAll);
    final data = response.data;
    if (data is! Map) return 0;
    return int.tryParse((data['updated_count'] ?? 0).toString()) ?? 0;
  }

  @override
  Future<int> clearAll() async {
    final response =
        await _dio.delete<dynamic>(ApiEndpoints.notificationsClearAll);
    final data = response.data;
    if (data is! Map) return 0;
    return int.tryParse((data['deleted_count'] ?? 0).toString()) ?? 0;
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationsRepositoryImpl(dio);
});
