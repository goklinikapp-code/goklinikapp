import 'auth_session.dart';
import 'signup_models.dart';

abstract class AuthRepository {
  Future<AuthSession> login(
      {required String identifier, required String password});

  Future<AuthSession> register({
    required String fullName,
    required String clinicId,
    required String email,
    required String phone,
    required String password,
    String? referralCode,
  });

  Future<List<SignupClinic>> fetchSignupClinics();

  Future<ReferralLookupResult> lookupReferralCode(String referralCode);

  Future<Map<String, dynamic>> refreshToken(String refreshToken);
}
