import 'postop_models.dart';

abstract class PostOpRepository {
  Future<PostOpJourney?> getMyJourney();
  Future<PostOpChecklistItem> completeChecklistItem(String checklistId);
  Future<PostOpChecklistItem> updateChecklistItem({
    required String checklistId,
    required bool completed,
  });
  Future<PostOperatoryCheckin> submitCheckin({
    required int painLevel,
    required bool hasFever,
    required String notes,
    String? journeyId,
  });
  Future<List<EvolutionPhotoItem>> getJourneyPhotos(String journeyId);
  Future<Map<String, dynamic>> uploadPhoto({
    required String journeyId,
    int? dayNumber,
    required String filePath,
    bool isAnonymous,
  });
  Future<CareCenterData> getCareCenter(String journeyId);
  Future<List<UrgentMedicalRequest>> getUrgentRequests();
  Future<UrgentMedicalRequest> sendUrgentRequest({required String question});
  Future<UrgentTicket> createUrgentTicket({
    required String message,
    String severity,
    String? imagePath,
  });
}
