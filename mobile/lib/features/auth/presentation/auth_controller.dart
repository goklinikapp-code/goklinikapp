import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/auth_storage.dart';
import '../data/auth_repository_impl.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';

const _patientRole = 'patient';

class AuthViewState {
  const AuthViewState({
    required this.initialized,
    required this.loading,
    required this.onboardingCompleted,
    this.session,
    this.errorMessage,
  });

  final bool initialized;
  final bool loading;
  final bool onboardingCompleted;
  final AuthSession? session;
  final String? errorMessage;

  bool get isAuthenticated =>
      session != null && session!.accessToken.isNotEmpty;

  AuthViewState copyWith({
    bool? initialized,
    bool? loading,
    bool? onboardingCompleted,
    AuthSession? session,
    String? errorMessage,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return AuthViewState(
      initialized: initialized ?? this.initialized,
      loading: loading ?? this.loading,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  static const initial = AuthViewState(
    initialized: false,
    loading: false,
    onboardingCompleted: false,
  );
}

class AuthController extends StateNotifier<AuthViewState> {
  AuthController(this._ref) : super(AuthViewState.initial);

  final Ref _ref;

  AuthStorage get _storage => _ref.read(authStorageProvider);
  bool _isRoleAllowed(String role) => role.trim().toLowerCase() == _patientRole;

  Future<void> init() async {
    List<dynamic> results;
    try {
      results = await Future.wait<dynamic>([
        _storage.isOnboardingCompleted(),
        _storage.readAccessToken(),
        _storage.readRefreshToken(),
        _storage.readUserJson(),
      ]);
    } catch (_) {
      state = state.copyWith(
        initialized: true,
        onboardingCompleted: false,
        clearSession: true,
        clearError: true,
      );
      return;
    }

    final onboardingDone = (results[0] as bool?) ?? false;
    final access = results[1] as String?;
    final refresh = results[2] as String?;
    final userJson = results[3] as String?;

    AuthSession? session;
    if (access != null && refresh != null && userJson != null) {
      try {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        session = AuthSession.fromJson({
          'access_token': access,
          'refresh_token': refresh,
          'user': userMap,
        });
      } catch (_) {
        session = null;
      }
    }

    if (session != null && !_isRoleAllowed(session.user.role)) {
      await _storage.clearSession();
      session = null;
    }

    state = state.copyWith(
      initialized: true,
      onboardingCompleted: onboardingDone,
      session: session,
      clearError: true,
    );
  }

  void markInitializedFallback() {
    state = state.copyWith(
      initialized: true,
      onboardingCompleted: false,
      clearSession: true,
      clearError: true,
    );
  }

  Future<bool> login(
      {required String identifier, required String password}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final repo = _ref.read(authRepositoryProvider);
      final session =
          await repo.login(identifier: identifier, password: password);
      if (session.accessToken.isEmpty ||
          session.refreshToken.isEmpty ||
          session.user.id.isEmpty) {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Resposta de login inválida. Verifique as credenciais.',
        );
        return false;
      }
      if (!_isRoleAllowed(session.user.role)) {
        await _storage.clearSession();
        state = state.copyWith(
          loading: false,
          clearSession: true,
          errorMessage:
              'Acesso nao autorizado. Este aplicativo e exclusivo para pacientes.',
        );
        return false;
      }
      await _storage.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      await _storage.saveUserJson(jsonEncode(session.user.toJson()));
      state =
          state.copyWith(loading: false, session: session, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
          loading: false, errorMessage: 'Falha no login. Verifique os dados.');
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String clinicId,
    required String email,
    required String phone,
    required String password,
    String? referralCode,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final repo = _ref.read(authRepositoryProvider);
      final session = await repo.register(
        fullName: fullName,
        clinicId: clinicId,
        email: email,
        phone: phone,
        password: password,
        referralCode: referralCode,
      );
      if (session.accessToken.isEmpty ||
          session.refreshToken.isEmpty ||
          session.user.id.isEmpty) {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Resposta de cadastro inválida. Tente novamente.',
        );
        return false;
      }
      if (!_isRoleAllowed(session.user.role)) {
        await _storage.clearSession();
        state = state.copyWith(
          loading: false,
          clearSession: true,
          errorMessage:
              'Acesso nao autorizado. Este aplicativo e exclusivo para pacientes.',
        );
        return false;
      }
      await _storage.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      await _storage.saveUserJson(jsonEncode(session.user.toJson()));
      state =
          state.copyWith(loading: false, session: session, clearError: true);
      return true;
    } catch (e) {
      state =
          state.copyWith(loading: false, errorMessage: 'Falha no cadastro.');
      return false;
    }
  }

  Future<void> completeOnboarding() async {
    await _storage.setOnboardingCompleted();
    state = state.copyWith(onboardingCompleted: true);
  }

  Future<void> logout() async {
    await _storage.clearSession();
    state = state.copyWith(clearSession: true, clearError: true);
  }

  void updateSessionTokens({
    required String accessToken,
    required String refreshToken,
  }) {
    final currentSession = state.session;
    if (currentSession == null) return;

    state = state.copyWith(
      session: AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: currentSession.user,
      ),
      clearError: true,
    );
  }

  Future<void> updateCurrentUser(AuthUser user) async {
    if (!_isRoleAllowed(user.role)) {
      await _storage.clearSession();
      state = state.copyWith(clearSession: true, clearError: true);
      return;
    }

    final currentSession = state.session;
    if (currentSession == null) return;

    await _storage.saveUserJson(jsonEncode(user.toJson()));
    state = state.copyWith(
      session: AuthSession(
        accessToken: currentSession.accessToken,
        refreshToken: currentSession.refreshToken,
        user: user,
      ),
      clearError: true,
    );
  }

  void clearSessionState() {
    state = state.copyWith(clearSession: true, clearError: true);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthViewState>((ref) {
  return AuthController(ref);
});
