import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReferralDeepLinkState {
  const ReferralDeepLinkState({
    this.pendingCode,
    this.lastRawUri,
  });

  final String? pendingCode;
  final String? lastRawUri;

  ReferralDeepLinkState copyWith({
    String? pendingCode,
    String? lastRawUri,
    bool clearPendingCode = false,
  }) {
    return ReferralDeepLinkState(
      pendingCode: clearPendingCode ? null : (pendingCode ?? this.pendingCode),
      lastRawUri: lastRawUri ?? this.lastRawUri,
    );
  }
}

class ReferralDeepLinkController extends StateNotifier<ReferralDeepLinkState> {
  ReferralDeepLinkController() : super(const ReferralDeepLinkState());

  void registerIncomingUri(Uri uri) {
    final code = extractReferralCodeFromUri(uri);
    if (code == null || code.isEmpty) {
      return;
    }
    state = state.copyWith(
      pendingCode: code,
      lastRawUri: uri.toString(),
    );
  }

  void clearPendingCode() {
    state = state.copyWith(clearPendingCode: true);
  }
}

String? extractReferralCodeFromUri(Uri? uri) {
  if (uri == null) return null;

  final scheme = uri.scheme.trim().toLowerCase();
  if (scheme != 'goklinik') return null;

  final host = uri.host.trim().toLowerCase();
  final segments = uri.pathSegments;

  String? rawCode;
  if (host == 'ref' && segments.isNotEmpty) {
    rawCode = segments.first;
  } else if (segments.length >= 2 && segments.first.toLowerCase() == 'ref') {
    rawCode = segments[1];
  }

  final normalized = (rawCode ?? '').trim().toUpperCase();
  if (normalized.isEmpty) return null;
  return normalized;
}

final referralDeepLinkProvider =
    StateNotifierProvider<ReferralDeepLinkController, ReferralDeepLinkState>(
        (ref) {
  return ReferralDeepLinkController();
});
