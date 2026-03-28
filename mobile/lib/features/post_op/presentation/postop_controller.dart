import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/postop_repository_impl.dart';
import '../domain/postop_models.dart';

class PostOpController extends StateNotifier<AsyncValue<PostOpJourney?>> {
  PostOpController(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _ref.read(postOpRepositoryProvider).getMyJourney());
  }

  Future<void> completeChecklist(String checklistId) async {
    await _ref.read(postOpRepositoryProvider).completeChecklistItem(checklistId);
    await load();
  }

  Future<void> uploadPhoto({
    required String journeyId,
    required int dayNumber,
    required String path,
    bool isAnonymous = false,
  }) async {
    await _ref.read(postOpRepositoryProvider).uploadPhoto(
          journeyId: journeyId,
          dayNumber: dayNumber,
          filePath: path,
          isAnonymous: isAnonymous,
        );
  }
}

final postOpControllerProvider =
    StateNotifierProvider<PostOpController, AsyncValue<PostOpJourney?>>((ref) {
  return PostOpController(ref);
});

final careCenterProvider = FutureProvider.family<CareCenterData, String>((ref, journeyId) {
  return ref.read(postOpRepositoryProvider).getCareCenter(journeyId);
});

final journeyPhotosProvider = FutureProvider.family<List<EvolutionPhotoItem>, String>((ref, journeyId) {
  return ref.read(postOpRepositoryProvider).getJourneyPhotos(journeyId);
});

class UrgentMedicalRequestsController
    extends StateNotifier<AsyncValue<List<UrgentMedicalRequest>>> {
  UrgentMedicalRequestsController(this._ref)
      : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = await AsyncValue.guard(
      () => _ref.read(postOpRepositoryProvider).getUrgentRequests(),
    );
  }

  Future<void> send(String question) async {
    await _ref.read(postOpRepositoryProvider).sendUrgentRequest(question: question);
    await load();
  }
}

final urgentMedicalRequestsProvider = StateNotifierProvider<
    UrgentMedicalRequestsController, AsyncValue<List<UrgentMedicalRequest>>>(
  (ref) => UrgentMedicalRequestsController(ref),
);
