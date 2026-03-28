import 'referral_models.dart';

abstract class ReferralsRepository {
  Future<ReferralSummary> getReferrals();
}
