import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/travel_plans_repository_impl.dart';
import '../domain/travel_plan_models.dart';

final travelPlanProvider = FutureProvider<TravelPlanModel?>((ref) async {
  return ref.read(travelPlansRepositoryProvider).getMyPlan();
});
