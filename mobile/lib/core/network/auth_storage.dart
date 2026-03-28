import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  AuthStorage(this._secureStorage);

  static const _accessTokenKey = 'gk_access_token';
  static const _refreshTokenKey = 'gk_refresh_token';
  static const _patientCpfKey = 'gk_patient_cpf';
  static const _userJsonKey = 'gk_user_json';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _biometricPromptDoneKey = 'biometric_prompt_done';

  final FlutterSecureStorage _secureStorage;
  static const _fallbackPrefix = 'fallback_';
  static const _secureTimeout = Duration(seconds: 2);

  Future<void> _writeSecureOrFallback(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value).timeout(_secureTimeout);
      return;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_fallbackPrefix$key', value);
    }
  }

  Future<String?> _readSecureOrFallback(String key) async {
    try {
      final value = await _secureStorage.read(key: key).timeout(_secureTimeout);
      if (value != null) return value;
    } catch (_) {
      // Fallback to shared preferences below.
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_fallbackPrefix$key');
  }

  Future<void> _deleteSecureAndFallback(String key) async {
    try {
      await _secureStorage.delete(key: key).timeout(_secureTimeout);
    } catch (_) {
      // Continue and clean fallback storage.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_fallbackPrefix$key');
  }

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _writeSecureOrFallback(_accessTokenKey, accessToken);
    await _writeSecureOrFallback(_refreshTokenKey, refreshToken);
  }

  Future<String?> readAccessToken() => _readSecureOrFallback(_accessTokenKey);

  Future<String?> readRefreshToken() => _readSecureOrFallback(_refreshTokenKey);

  Future<void> saveCpf(String cpf) => _writeSecureOrFallback(_patientCpfKey, cpf);

  Future<String?> readCpf() => _readSecureOrFallback(_patientCpfKey);

  Future<void> clearSession() async {
    await _deleteSecureAndFallback(_accessTokenKey);
    await _deleteSecureAndFallback(_refreshTokenKey);
    await _deleteSecureAndFallback(_patientCpfKey);
    await _deleteSecureAndFallback(_userJsonKey);
  }

  Future<void> saveUserJson(String json) => _writeSecureOrFallback(_userJsonKey, json);

  Future<String?> readUserJson() => _readSecureOrFallback(_userJsonKey);

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
  }

  Future<bool> isBiometricPromptDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricPromptDoneKey) ?? false;
  }

  Future<void> setBiometricPromptDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricPromptDoneKey, true);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authStorageProvider = Provider<AuthStorage>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthStorage(secureStorage);
});
