import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/network/auth_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_button.dart';

class BiometricPromptScreen extends ConsumerStatefulWidget {
  const BiometricPromptScreen({super.key});

  @override
  ConsumerState<BiometricPromptScreen> createState() => _BiometricPromptScreenState();
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
    setState(() => _loading = true);
    try {
      await _localAuth.authenticate(
        localizedReason: 'Ative biometria para acesso rápido e seguro',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
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
                    const Icon(Icons.fingerprint, size: 68, color: GKColors.primary),
                    const SizedBox(height: 16),
                    Text('Acesso Rápido e Seguro', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Text(
                      'Ative biometria para entrar no app com mais praticidade e segurança.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    GKButton(
                      label: 'Ativar Biometria',
                      icon: const Icon(Icons.fingerprint, color: Colors.white),
                      onPressed: _enableBiometrics,
                      isLoading: _loading,
                    ),
                    TextButton(onPressed: _finish, child: const Text('Agora não')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: GKColors.tealIce,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'PROTOCOLO DE SEGURANÇA ATIVO',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: GKColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
