import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pre_operatory_repository_impl.dart';
import '../domain/pre_operatory_models.dart';

class PreOperatoryController
    extends StateNotifier<AsyncValue<PreOperatoryRecord?>> {
  PreOperatoryController(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _ref.read(preOperatoryRepositoryProvider).getMyPreOperatory(),
    );
  }

  Future<PreOperatoryRecord> submit(PreOperatoryUpsertPayload payload) async {
    final current = state.valueOrNull;
    final repository = _ref.read(preOperatoryRepositoryProvider);

    final saved = current == null
        ? await repository.createPreOperatory(payload)
        : await repository.updatePreOperatory(current.id, payload);

    state = AsyncValue.data(saved);
    return saved;
  }
}

final preOperatoryControllerProvider = StateNotifierProvider<
    PreOperatoryController, AsyncValue<PreOperatoryRecord?>>((ref) {
  return PreOperatoryController(ref);
});
