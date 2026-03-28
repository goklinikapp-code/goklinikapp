import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/referral_models.dart';
import '../domain/referrals_repository.dart';

class ReferralsRepositoryImpl implements ReferralsRepository {
  ReferralsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ReferralSummary> getReferrals() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.referralsMyReferrals);
    final data =
        response.data as Map<String, dynamic>? ?? const <String, dynamic>{};
    return ReferralSummary.fromJson(data);
  }
}

final referralsRepositoryProvider = Provider<ReferralsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ReferralsRepositoryImpl(dio);
});
