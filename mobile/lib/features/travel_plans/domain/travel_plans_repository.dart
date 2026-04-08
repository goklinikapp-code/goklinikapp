import 'travel_plan_models.dart';

abstract class TravelPlansRepository {
  Future<TravelPlanModel?> getMyPlan();

  Future<TransferItem> confirmTransfer(String transferId);
}
