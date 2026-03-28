import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../utils/app_logger.dart';
import 'api_endpoints.dart';
import 'auth_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(authStorageProvider);
  final configuredBaseUrl = (dotenv.env['API_BASE_URL'] ?? 'https://api.goklinik.com').trim();
  final normalized = configuredBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final baseUrl = normalized.endsWith('/api')
      ? normalized.substring(0, normalized.length - 4)
      : normalized;

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final inMemoryToken = ref.read(authControllerProvider).session?.accessToken;
        final token = (inMemoryToken != null && inMemoryToken.isNotEmpty)
            ? inMemoryToken
            : await storage.readAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        final isUnauthorized = error.response?.statusCode == 401;
        final shouldSkipRefresh = request.headers['x-skip-auth-refresh'] == true;
        final isRefreshRequest = request.path == ApiEndpoints.authRefresh;
        final alreadyRetried = request.extra['retry'] == true;

        Future<void> invalidateAuthState() async {
          await storage.clearSession();
          // Keep Riverpod auth state in sync with persisted storage so router
          // can redirect to /login instead of keeping the user on protected routes.
          ref.read(authControllerProvider.notifier).clearSessionState();
        }

        if (isUnauthorized && alreadyRetried) {
          await invalidateAuthState();
          handler.next(error);
          return;
        }

        if (!isUnauthorized || shouldSkipRefresh || isRefreshRequest || alreadyRetried) {
          handler.next(error);
          return;
        }

        final inMemoryRefreshToken = ref.read(authControllerProvider).session?.refreshToken;
        final refreshToken = (inMemoryRefreshToken != null && inMemoryRefreshToken.isNotEmpty)
            ? inMemoryRefreshToken
            : await storage.readRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          await invalidateAuthState();
          handler.next(error);
          return;
        }

        try {
          final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
          final refreshResponse = await refreshDio.post<dynamic>(
            ApiEndpoints.authRefresh,
            data: {'refresh': refreshToken},
            options: Options(headers: {'x-skip-auth-refresh': true}),
          );

          final newAccess = (refreshResponse.data['access'] ?? refreshResponse.data['access_token'] ?? '')
              .toString();
          final newRefresh = (refreshResponse.data['refresh'] ?? refreshResponse.data['refresh_token'] ?? refreshToken)
              .toString();

          if (newAccess.isEmpty) {
            await invalidateAuthState();
            handler.next(error);
            return;
          }

          await storage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
          ref
              .read(authControllerProvider.notifier)
              .updateSessionTokens(accessToken: newAccess, refreshToken: newRefresh);

          request.headers['Authorization'] = 'Bearer $newAccess';
          request.extra['retry'] = true;
          final retryResponse = await dio.fetch<dynamic>(request);
          handler.resolve(retryResponse);
        } catch (refreshError, stackTrace) {
          AppLogger.error('Token refresh failed', refreshError, stackTrace);
          await invalidateAuthState();
          handler.next(error);
        }
      },
    ),
  );

  return dio;
});
