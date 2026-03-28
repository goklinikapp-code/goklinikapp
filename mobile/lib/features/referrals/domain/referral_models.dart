class ReferralItem {
  const ReferralItem({
    required this.id,
    required this.referredName,
    required this.referredEmail,
    required this.status,
    required this.commissionValue,
    required this.createdAt,
  });

  final String id;
  final String referredName;
  final String referredEmail;
  final String status;
  final double commissionValue;
  final DateTime? createdAt;

  factory ReferralItem.fromJson(Map<String, dynamic> json) {
    return ReferralItem(
      id: (json['id'] ?? '').toString(),
      referredName: (json['referred_name'] ?? '').toString(),
      referredEmail: (json['referred_email'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      commissionValue:
          double.tryParse((json['commission_value'] ?? 0).toString()) ?? 0,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}

class ReferralSummary {
  const ReferralSummary({
    required this.referralCode,
    required this.referralLink,
    required this.totalPending,
    required this.totalConverted,
    required this.totalPaid,
    required this.totalCommissionPending,
    required this.totalCommissionPaid,
    required this.items,
  });

  final String referralCode;
  final String referralLink;
  final int totalPending;
  final int totalConverted;
  final int totalPaid;
  final double totalCommissionPending;
  final double totalCommissionPaid;
  final List<ReferralItem> items;

  int get totalReferrals => totalPending + totalConverted + totalPaid;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? const [];
    return ReferralSummary(
      referralCode: (json['referral_code'] ?? '').toString(),
      referralLink: (json['referral_link'] ?? '').toString(),
      totalPending: int.tryParse((json['total_pending'] ?? 0).toString()) ?? 0,
      totalConverted:
          int.tryParse((json['total_converted'] ?? 0).toString()) ?? 0,
      totalPaid: int.tryParse((json['total_paid'] ?? 0).toString()) ?? 0,
      totalCommissionPending:
          double.tryParse((json['total_commission_pending'] ?? 0).toString()) ??
              0,
      totalCommissionPaid:
          double.tryParse((json['total_commission_paid'] ?? 0).toString()) ?? 0,
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(ReferralItem.fromJson)
          .toList(),
    );
  }
}
