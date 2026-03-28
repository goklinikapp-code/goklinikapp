import 'financial_models.dart';

abstract class FinancialRepository {
  Future<FinancialSummary> getFinancialSummary();
}
