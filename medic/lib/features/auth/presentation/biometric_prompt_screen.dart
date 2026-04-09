import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/network/auth_storage.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_button.dart';

class BiometricPromptScreen extends ConsumerStatefulWidget {
  const BiometricPromptScreen({super.key});

  @override
  ConsumerState<BiometricPromptScreen> createState() =>
      _BiometricPromptScreenState();
}

class _BiometricPromptScreenState extends ConsumerState<BiometricPromptScreen> {
  final _localAuth = LocalAuthentication();
  bool _loading = false;

  Future<void> _finish() async {
    await ref.read(authStorageProvider).setBiometricPromptDone();
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _enableBiometrics() async {
    final language = Localizations.localeOf(context).languageCode;
    setState(() => _loading = true);
    try {
      await _localAuth.authenticate(
        localizedReason:
            appTr(key: 'biometric_auth_reason', language: language),
        options:
            const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      await _finish();
    } catch (_) {
      await _finish();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => _t(context, key);
    return Scaffold(
      backgroundColor: GKColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.fingerprint,
                        size: 68, color: GKColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      t('biometric_prompt_title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t('biometric_prompt_subtitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    GKButton(
                      label: t('biometric_prompt_enable'),
                      icon: const Icon(Icons.fingerprint, color: Colors.white),
                      onPressed: _enableBiometrics,
                      isLoading: _loading,
                    ),
                    TextButton(
                      onPressed: _finish,
                      child: Text(t('biometric_prompt_not_now')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: GKColors.tealIce,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  t('biometric_prompt_security_badge'),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: GKColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _t(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  return appTr(key: key, language: language);
}
