import 'home_models.dart';

abstract class HomeRepository {
  Future<HomeData> getHomeData({required String userName});
}
