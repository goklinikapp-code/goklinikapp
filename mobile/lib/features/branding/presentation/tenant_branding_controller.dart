import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../domain/tenant_branding.dart';

class TenantBrandingController extends StateNotifier<TenantBranding> {
  TenantBrandingController(this._ref) : super(TenantBranding.defaultBranding);

  final Ref _ref;
  Timer? _pollingTimer;
  String? _activeTenantSlug;

  Dio get _dio => _ref.read(dioProvider);

  Future<void> syncWithAuthState(AuthViewState authState) async {
    final slug = authState.session?.user.tenant?.slug;
    if (!authState.isAuthenticated || slug == null || slug.trim().isEmpty) {
      clear();
      return;
    }

    final normalizedSlug = slug.trim();
    if (_activeTenantSlug != normalizedSlug) {
      _activeTenantSlug = normalizedSlug;
      await _fetchBranding(normalizedSlug);
      _restartPolling();
      return;
    }

    if (_pollingTimer == null || !_pollingTimer!.isActive) {
      _restartPolling();
    }
  }

  Future<void> refresh() async {
    final slug = _activeTenantSlug;
    if (slug == null || slug.isEmpty) {
      return;
    }
    await _fetchBranding(slug);
  }

  void clear() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _activeTenantSlug = null;
    state = TenantBranding.defaultBranding;
  }

  Future<void> _fetchBranding(String slug) async {
    try {
      final response =
          await _dio.get<dynamic>(ApiEndpoints.publicTenantBranding(slug));
      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        state = TenantBranding.fromJson(payload);
        return;
      }
      if (payload is Map) {
        state = TenantBranding.fromJson(Map<String, dynamic>.from(payload));
      }
    } catch (_) {
      if (state.slug != slug) {
        state = TenantBranding.defaultBranding;
      }
    }
  }

  void _restartPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      refresh();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final tenantBrandingProvider =
    StateNotifierProvider<TenantBrandingController, TenantBranding>((ref) {
  return TenantBrandingController(ref);
});
