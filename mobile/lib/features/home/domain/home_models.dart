import '../../appointments/domain/appointment_models.dart';

class HomeData {
  const HomeData({
    required this.userName,
    required this.unreadNotifications,
    required this.nextAppointments,
  });

  final String userName;
  final int unreadNotifications;
  final List<AppointmentItem> nextAppointments;
}
