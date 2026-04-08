import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/travel_plan_models.dart';
import '../domain/travel_plans_repository.dart';

class TravelPlansRepositoryImpl implements TravelPlansRepository {
  TravelPlansRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<TravelPlanModel?> getMyPlan() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.travelPlansMyPlan);
      return TravelPlanModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<TransferItem> confirmTransfer(String transferId) async {
    final response = await _dio.put<dynamic>(
      ApiEndpoints.travelPlansConfirmTransfer(transferId),
    );
    return TransferItem.fromJson(response.data as Map<String, dynamic>);
  }
}

final travelPlansRepositoryProvider = Provider<TravelPlansRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return TravelPlansRepositoryImpl(dio);
});
