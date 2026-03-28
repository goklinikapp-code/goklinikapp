import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/notifications/data/notifications_repository_impl.dart';
import '../../features/notifications/presentation/notifications_controller.dart';

class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;

  Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen((_) {
        _ref.read(notificationsControllerProvider.notifier).load();
      });

      await registerTokenIfAuthenticated();
    } catch (_) {
      // Keep app working without Firebase setup in local development.
    }
  }

  Future<void> registerTokenIfAuthenticated() async {
    try {
      final session = _ref.read(authControllerProvider).session;
      if (session == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final platform = Platform.isIOS ? 'ios' : 'android';
      await _ref.read(notificationsRepositoryProvider).registerToken(token: token, platform: platform);
    } catch (_) {
      // Ignore registration failures when Firebase is not fully configured.
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});
