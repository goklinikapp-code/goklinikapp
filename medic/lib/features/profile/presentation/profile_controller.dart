import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_user.dart';
import '../data/profile_repository_impl.dart';

final profileProvider = FutureProvider<AuthUser?>((ref) {
  return ref.read(profileRepositoryProvider).getCurrentUser();
});
