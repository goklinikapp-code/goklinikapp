import 'postop_models.dart';

abstract class PostOpRepository {
  Future<PostOpJourney?> getMyJourney();
  Future<PostOpChecklistItem> completeChecklistItem(String checklistId);
  Future<List<EvolutionPhotoItem>> getJourneyPhotos(String journeyId);
  Future<Map<String, dynamic>> uploadPhoto({
    required String journeyId,
    required int dayNumber,
    required String filePath,
    bool isAnonymous,
  });
  Future<CareCenterData> getCareCenter(String journeyId);
  Future<List<UrgentMedicalRequest>> getUrgentRequests();
  Future<UrgentMedicalRequest> sendUrgentRequest({required String question});
}
