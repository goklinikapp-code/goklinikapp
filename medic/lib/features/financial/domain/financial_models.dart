class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.status,
    required this.dueDate,
    required this.paidAt,
    required this.paymentMethod,
  });

  final String id;
  final String description;
  final double amount;
  final String status;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String paymentMethod;

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: (json['id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      amount: double.tryParse((json['amount'] ?? 0).toString()) ?? 0,
      status: (json['status'] ?? '').toString(),
      dueDate: DateTime.tryParse((json['due_date'] ?? '').toString()),
      paidAt: DateTime.tryParse((json['paid_at'] ?? '').toString()),
      paymentMethod: (json['payment_method'] ?? '').toString(),
    );
  }
}

class SessionPackageItem {
  const SessionPackageItem({
    required this.id,
    required this.packageName,
    required this.totalSessions,
    required this.usedSessions,
    required this.sessionsRemaining,
    required this.totalAmount,
    required this.purchaseDate,
    required this.specialty,
  });

  final String id;
  final String packageName;
  final int totalSessions;
  final int usedSessions;
  final int sessionsRemaining;
  final double totalAmount;
  final DateTime? purchaseDate;
  final String specialty;

  factory SessionPackageItem.fromJson(Map<String, dynamic> json) {
    final specialty = json['specialty'];
    return SessionPackageItem(
      id: (json['id'] ?? '').toString(),
      packageName: (json['package_name'] ?? '').toString(),
      totalSessions: int.tryParse((json['total_sessions'] ?? 0).toString()) ?? 0,
      usedSessions: int.tryParse((json['used_sessions'] ?? 0).toString()) ?? 0,
      sessionsRemaining: int.tryParse((json['sessions_remaining'] ?? 0).toString()) ?? 0,
      totalAmount: double.tryParse((json['total_amount'] ?? 0).toString()) ?? 0,
      purchaseDate: DateTime.tryParse((json['purchase_date'] ?? '').toString()),
      specialty: specialty is Map<String, dynamic> ? (specialty['name'] ?? '').toString() : '',
    );
  }
}

class FinancialSummary {
  const FinancialSummary({
    required this.nextDue,
    required this.openBalance,
    required this.transactions,
    required this.packages,
  });

  final TransactionItem? nextDue;
  final double openBalance;
  final List<TransactionItem> transactions;
  final List<SessionPackageItem> packages;
}
