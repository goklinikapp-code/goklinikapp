import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/home_repository_impl.dart';
import '../domain/home_models.dart';

final homeProvider = FutureProvider<HomeData>((ref) async {
  final session = ref.watch(authControllerProvider).session;
  final userName = session?.user.fullName.split(' ').first ?? 'Paciente';
  return ref.read(homeRepositoryProvider).getHomeData(userName: userName);
});
