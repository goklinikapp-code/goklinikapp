import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/data/appointments_repository_impl.dart';
import '../../notifications/data/notifications_repository_impl.dart';
import '../domain/home_models.dart';
import '../domain/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._ref);

  final Ref _ref;

  @override
  Future<HomeData> getHomeData({required String userName}) async {
    final appointmentsRepo = _ref.read(appointmentsRepositoryProvider);
    final notificationsRepo = _ref.read(notificationsRepositoryProvider);

    final appointments = await appointmentsRepo.getAppointments();
    final unread = await notificationsRepo.getUnreadCount();

    return HomeData(
      userName: userName,
      unreadNotifications: unread,
      nextAppointments: appointments.where((item) => item.dateTime.isAfter(DateTime.now())).toList(),
    );
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl(ref);
});
