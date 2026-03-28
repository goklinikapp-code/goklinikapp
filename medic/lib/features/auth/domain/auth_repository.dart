import 'auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> login(
      {required String identifier, required String password});

  Future<AuthSession> register({
    required String fullName,
    required String cpf,
    required String email,
    required String phone,
    required String dateOfBirth,
    required String password,
    String? referralCode,
  });

  Future<Map<String, dynamic>> refreshToken(String refreshToken);
}
