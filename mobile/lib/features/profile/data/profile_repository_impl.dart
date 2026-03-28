import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._ref, this._dio);

  final Ref _ref;
  final Dio _dio;

  @override
  Future<AuthUser?> getCurrentUser() async {
    return _ref.read(authControllerProvider).session?.user;
  }

  @override
  Future<AuthUser> uploadAvatar({required String filePath}) async {
    final file = File(filePath);
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'avatar.jpg';
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final response = await _dio.post<dynamic>(
      ApiEndpoints.authMeAvatar,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return AuthUser.fromJson(response.data as Map<String, dynamic>);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ProfileRepositoryImpl(ref, dio);
});
