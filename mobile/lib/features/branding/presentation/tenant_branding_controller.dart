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
        state = _normalizeAssetUrls(TenantBranding.fromJson(payload));
        return;
      }
      if (payload is Map) {
        state = _normalizeAssetUrls(
          TenantBranding.fromJson(Map<String, dynamic>.from(payload)),
        );
      }
    } catch (_) {
      if (state.slug != slug) {
        state = TenantBranding.defaultBranding;
      }
    }
  }

  TenantBranding _normalizeAssetUrls(TenantBranding branding) {
    return branding.copyWith(
      logoUrl: _normalizeAssetUrl(branding.logoUrl),
      faviconUrl: _normalizeAssetUrl(branding.faviconUrl),
    );
  }

  String? _normalizeAssetUrl(String? rawUrl) {
    final value = (rawUrl ?? '').trim();
    if (value.isEmpty) {
      return null;
    }

    final apiBase = Uri.tryParse(_dio.options.baseUrl);
    final source = Uri.tryParse(value);
    if (apiBase == null || apiBase.host.isEmpty || source == null) {
      return value;
    }

    if (!source.hasScheme && value.startsWith('/')) {
      return apiBase
          .replace(
            path: value,
            query: source.query.isEmpty ? null : source.query,
            fragment: source.fragment.isEmpty ? null : source.fragment,
          )
          .toString();
    }

    if (!source.hasScheme || source.host != 'localhost') {
      return value;
    }

    return source
        .replace(
          host: apiBase.host,
          port: apiBase.hasPort ? apiBase.port : source.port,
        )
        .toString();
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
