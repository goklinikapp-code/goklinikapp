import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/financial_models.dart';
import '../domain/financial_repository.dart';

class FinancialRepositoryImpl implements FinancialRepository {
  FinancialRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<FinancialSummary> getFinancialSummary() async {
    final transactionsResponse = await _dio.get<dynamic>(ApiEndpoints.financialMyTransactions);
    final packagesResponse = await _dio.get<dynamic>(ApiEndpoints.financialMyPackages);

    final txData = transactionsResponse.data as Map<String, dynamic>;
    final txList = (txData['transactions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TransactionItem.fromJson)
        .toList();

    final nextDueJson = txData['next_due'];
    final nextDue = nextDueJson is Map<String, dynamic> ? TransactionItem.fromJson(nextDueJson) : null;
    final openBalance = double.tryParse((txData['open_balance'] ?? 0).toString()) ?? 0;

    final packageData = packagesResponse.data as List<dynamic>? ?? const [];
    final packages = packageData
        .whereType<Map<String, dynamic>>()
        .map(SessionPackageItem.fromJson)
        .toList();

    return FinancialSummary(
      nextDue: nextDue,
      openBalance: openBalance,
      transactions: txList,
      packages: packages,
    );
  }
}

final financialRepositoryProvider = Provider<FinancialRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return FinancialRepositoryImpl(dio);
});
