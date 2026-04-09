import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/formatters.dart';

const supportedLanguages = <String>['tr', 'ru', 'en', 'de', 'es', 'pt'];
const supportedCurrencies = <String>['EUR', 'USD', 'CHF', 'TRY'];

const languageLabels = <String, String>{
  'tr': 'Türkçe',
  'ru': 'Russkiy',
  'en': 'English',
  'de': 'Deutsch',
  'es': 'Español',
  'pt': 'Português',
};

const currencyLabels = <String, String>{
  'EUR': 'Euro (EUR)',
  'USD': 'US Dollar (USD)',
  'CHF': 'Swiss Franc (CHF)',
  'TRY': 'Turkish Lira (TRY)',
};

const _localeByLanguage = <String, String>{
  'tr': 'tr_TR',
  'ru': 'ru_RU',
  'en': 'en_US',
  'de': 'de_DE',
  'es': 'es_ES',
  'pt': 'pt_BR',
};

String normalizeLanguage(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'en';
  }
  final normalized = value.trim().toLowerCase().split(RegExp(r'[-_]')).first;
  return supportedLanguages.contains(normalized) ? normalized : 'en';
}

String normalizeCurrency(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'USD';
  }
  final normalized = value.trim().toUpperCase();
  return supportedCurrencies.contains(normalized) ? normalized : 'USD';
}

String localeFromLanguage(String language) {
  return _localeByLanguage[normalizeLanguage(language)] ?? 'en_US';
}

String detectLanguageFromDevice() {
  final deviceLanguage = PlatformDispatcher.instance.locale.languageCode;
  return normalizeLanguage(deviceLanguage);
}

String defaultCurrencyForLanguage(String language) {
  final normalized = normalizeLanguage(language);
  if (normalized == 'tr') return 'TRY';
  if (normalized == 'en') return 'USD';
  if (<String>{'ru', 'de', 'es', 'pt'}.contains(normalized)) return 'EUR';
  return 'USD';
}

class AppPreferencesState {
  const AppPreferencesState({
    required this.language,
    required this.currency,
    required this.languageMode,
    required this.currencyMode,
    required this.darkMode,
    required this.initialized,
  });

  final String language;
  final String currency;
  final String languageMode;
  final String currencyMode;
  final bool darkMode;
  final bool initialized;

  AppPreferencesState copyWith({
    String? language,
    String? currency,
    String? languageMode,
    String? currencyMode,
    bool? darkMode,
    bool? initialized,
  }) {
    return AppPreferencesState(
      language: language ?? this.language,
      currency: currency ?? this.currency,
      languageMode: languageMode ?? this.languageMode,
      currencyMode: currencyMode ?? this.currencyMode,
      darkMode: darkMode ?? this.darkMode,
      initialized: initialized ?? this.initialized,
    );
  }

  String get localeTag => localeFromLanguage(language);
}

class AppPreferencesController extends StateNotifier<AppPreferencesState> {
  AppPreferencesController()
      : super(
          const AppPreferencesState(
            language: 'en',
            currency: 'USD',
            languageMode: 'auto',
            currencyMode: 'auto',
            darkMode: false,
            initialized: false,
          ),
        ) {
    Future<void>.microtask(initialize);
  }

  static const _languageKey = 'gk_language';
  static const _currencyKey = 'gk_currency';
  static const _languageModeKey = 'gk_language_mode';
  static const _currencyModeKey = 'gk_currency_mode';
  static const _darkModeKey = 'gk_dark_mode';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final storedLanguage = normalizeLanguage(prefs.getString(_languageKey));
    final storedCurrency = normalizeCurrency(prefs.getString(_currencyKey));
    final storedLanguageMode =
        prefs.getString(_languageModeKey) == 'manual' ? 'manual' : 'auto';
    final storedCurrencyMode =
        prefs.getString(_currencyModeKey) == 'manual' ? 'manual' : 'auto';
    final storedDarkMode = prefs.getBool(_darkModeKey) ?? false;

    final resolvedLanguage = storedLanguageMode == 'manual'
        ? storedLanguage
        : detectLanguageFromDevice();
    final resolvedCurrency = storedCurrencyMode == 'manual'
        ? storedCurrency
        : defaultCurrencyForLanguage(resolvedLanguage);

    await _applyIntlConfiguration(
        language: resolvedLanguage, currency: resolvedCurrency);
    state = state.copyWith(
      language: resolvedLanguage,
      currency: resolvedCurrency,
      languageMode: storedLanguageMode,
      currencyMode: storedCurrencyMode,
      darkMode: storedDarkMode,
      initialized: true,
    );
  }

  Future<void> setLanguage(String language) async {
    final normalizedLanguage = normalizeLanguage(language);
    final resolvedCurrency = state.currencyMode == 'manual'
        ? normalizeCurrency(state.currency)
        : defaultCurrencyForLanguage(normalizedLanguage);

    await _applyIntlConfiguration(
        language: normalizedLanguage, currency: resolvedCurrency);
    state = state.copyWith(
      language: normalizedLanguage,
      currency: resolvedCurrency,
      languageMode: 'manual',
      initialized: true,
    );
    await _persist();
  }

  Future<void> setCurrency(String currency) async {
    final normalizedCurrency = normalizeCurrency(currency);
    await _applyIntlConfiguration(
        language: state.language, currency: normalizedCurrency);
    state = state.copyWith(
      currency: normalizedCurrency,
      currencyMode: 'manual',
      initialized: true,
    );
    await _persist();
  }

  Future<void> useAutomaticLanguage() async {
    final resolvedLanguage = detectLanguageFromDevice();
    final resolvedCurrency = state.currencyMode == 'manual'
        ? normalizeCurrency(state.currency)
        : defaultCurrencyForLanguage(resolvedLanguage);
    await _applyIntlConfiguration(
        language: resolvedLanguage, currency: resolvedCurrency);
    state = state.copyWith(
      language: resolvedLanguage,
      currency: resolvedCurrency,
      languageMode: 'auto',
      initialized: true,
    );
    await _persist();
  }

  Future<void> useAutomaticCurrency() async {
    final resolvedCurrency = defaultCurrencyForLanguage(state.language);
    await _applyIntlConfiguration(
        language: state.language, currency: resolvedCurrency);
    state = state.copyWith(
      currency: resolvedCurrency,
      currencyMode: 'auto',
      initialized: true,
    );
    await _persist();
  }

  Future<void> setDarkMode(bool enabled) async {
    state = state.copyWith(darkMode: enabled, initialized: true);
    await _persist();
  }

  Future<void> _applyIntlConfiguration({
    required String language,
    required String currency,
  }) async {
    final localeTag = localeFromLanguage(language);
    await initializeDateFormatting(localeTag);
    Intl.defaultLocale = localeTag;
    FormatterConfig.configure(locale: localeTag, currency: currency);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, state.language);
    await prefs.setString(_currencyKey, state.currency);
    await prefs.setString(_languageModeKey, state.languageMode);
    await prefs.setString(_currencyModeKey, state.currencyMode);
    await prefs.setBool(_darkModeKey, state.darkMode);
  }
}

final appPreferencesControllerProvider =
    StateNotifierProvider<AppPreferencesController, AppPreferencesState>((ref) {
  return AppPreferencesController();
});
