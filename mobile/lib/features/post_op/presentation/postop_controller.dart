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
    state = await AsyncValue.guard(
        () => _ref.read(postOpRepositoryProvider).getMyJourney());
  }

  Future<void> completeChecklist(String checklistId) async {
    await _ref
        .read(postOpRepositoryProvider)
        .completeChecklistItem(checklistId);
    await load();
  }

  Future<void> updateChecklist({
    required String checklistId,
    required bool completed,
  }) async {
    await _ref.read(postOpRepositoryProvider).updateChecklistItem(
          checklistId: checklistId,
          completed: completed,
        );
    await load();
  }

  Future<PostOperatoryCheckin> submitCheckin({
    required int painLevel,
    required bool hasFever,
    required String notes,
    String? journeyId,
  }) async {
    final checkin = await _ref.read(postOpRepositoryProvider).submitCheckin(
          painLevel: painLevel,
          hasFever: hasFever,
          notes: notes,
          journeyId: journeyId,
        );
    await load();
    return checkin;
  }

  Future<void> uploadPhoto({
    required String journeyId,
    int? dayNumber,
    required String path,
    bool isAnonymous = false,
  }) async {
    await _ref.read(postOpRepositoryProvider).uploadPhoto(
          journeyId: journeyId,
          dayNumber: dayNumber,
          filePath: path,
          isAnonymous: isAnonymous,
        );
    await load();
  }

  Future<UrgentTicket> createUrgentTicket({
    required String message,
    String severity = 'high',
    String? imagePath,
  }) async {
    final ticket = await _ref.read(postOpRepositoryProvider).createUrgentTicket(
          message: message,
          severity: severity,
          imagePath: imagePath,
        );
    return ticket;
  }
}

final postOpControllerProvider =
    StateNotifierProvider<PostOpController, AsyncValue<PostOpJourney?>>((ref) {
  return PostOpController(ref);
});

final careCenterProvider =
    FutureProvider.family<CareCenterData, String>((ref, journeyId) {
  return ref.read(postOpRepositoryProvider).getCareCenter(journeyId);
});

final journeyPhotosProvider =
    FutureProvider.family<List<EvolutionPhotoItem>, String>((ref, journeyId) {
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
    await _ref
        .read(postOpRepositoryProvider)
        .sendUrgentRequest(question: question);
    await load();
  }
}

final urgentMedicalRequestsProvider = StateNotifierProvider<
    UrgentMedicalRequestsController, AsyncValue<List<UrgentMedicalRequest>>>(
  (ref) => UrgentMedicalRequestsController(ref),
);
