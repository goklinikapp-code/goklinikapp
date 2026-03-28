import '../../auth/domain/auth_user.dart';

abstract class ProfileRepository {
  Future<AuthUser?> getCurrentUser();
  Future<AuthUser> uploadAvatar({required String filePath});
}
