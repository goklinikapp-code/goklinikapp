import 'pre_operatory_models.dart';

abstract class PreOperatoryRepository {
  Future<PreOperatoryRecord?> getMyPreOperatory();

  Future<PreOperatoryRecord> createPreOperatory(
    PreOperatoryUpsertPayload payload,
  );

  Future<PreOperatoryRecord> updatePreOperatory(
    String preOperatoryId,
    PreOperatoryUpsertPayload payload,
  );
}
