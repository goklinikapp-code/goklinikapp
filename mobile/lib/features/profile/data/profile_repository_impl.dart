import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._ref, this._dio);

  final Ref _ref;
  final Dio _dio;

  static const Map<String, String> _imageMimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'tif': 'image/tiff',
    'tiff': 'image/tiff',
  };

  MediaType _resolveAvatarMediaType(String fileName) {
    final parts = fileName.split('.');
    final extension = parts.length > 1 ? parts.last.trim().toLowerCase() : '';
    final mime = _imageMimeByExtension[extension] ?? 'image/jpeg';
    final chunks = mime.split('/');
    if (chunks.length != 2) {
      return MediaType('image', 'jpeg');
    }
    return MediaType(chunks.first, chunks.last);
  }

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
    final mediaType = _resolveAvatarMediaType(fileName);
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: mediaType,
      ),
    });

    final response = await _dio.post<dynamic>(
      ApiEndpoints.authMeAvatar,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return AuthUser.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post<dynamic>(
      ApiEndpoints.authChangePassword,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ProfileRepositoryImpl(ref, dio);
});
