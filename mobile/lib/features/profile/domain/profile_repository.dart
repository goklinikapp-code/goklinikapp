import '../../auth/domain/auth_user.dart';

abstract class ProfileRepository {
  Future<AuthUser?> getCurrentUser();
  Future<AuthUser> uploadAvatar({required String filePath});
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
