import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/financial_repository_impl.dart';
import '../domain/financial_models.dart';

final financialProvider = FutureProvider<FinancialSummary>((ref) {
  return ref.read(financialRepositoryProvider).getFinancialSummary();
});
