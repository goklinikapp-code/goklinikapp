import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/referrals_repository_impl.dart';
import '../domain/referral_models.dart';

final referralsProvider = FutureProvider<ReferralSummary>((ref) {
  return ref.read(referralsRepositoryProvider).getReferrals();
});
