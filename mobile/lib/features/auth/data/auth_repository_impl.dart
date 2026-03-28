import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/signup_models.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<AuthSession> login(
      {required String identifier, required String password}) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.authLogin,
      data: {
        'identifier': identifier,
        'password': password,
      },
    );
    return AuthSession.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AuthSession> register({
    required String fullName,
    required String clinicId,
    required String email,
    required String phone,
    required String password,
    String? referralCode,
  }) async {
    final payload = <String, dynamic>{
      'full_name': fullName,
      'clinic_id': clinicId,
      'email': email,
      'phone': phone,
      'password': password,
    };
    if ((referralCode ?? '').trim().isNotEmpty) {
      payload['referral_code'] = referralCode!.trim();
    }

    final response = await _dio.post<dynamic>(
      ApiEndpoints.authRegister,
      data: payload,
    );
    return AuthSession.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<SignupClinic>> fetchSignupClinics() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.publicSignupClinics);
    final rawList = (response.data as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>();
    return rawList.map(SignupClinic.fromJson).toList(growable: false);
  }

  @override
  Future<ReferralLookupResult> lookupReferralCode(String referralCode) async {
    final normalized = referralCode.trim();
    final response =
        await _dio.get<dynamic>(ApiEndpoints.publicReferralLookup(normalized));
    return ReferralLookupResult.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.authRefresh,
      data: {'refresh': refreshToken},
      options: Options(headers: {'x-skip-auth-refresh': true}),
    );
    return response.data as Map<String, dynamic>;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepositoryImpl(dio);
});
