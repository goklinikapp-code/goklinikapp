import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';

final profileProvider = Provider<AuthUser?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.session?.user;
});
