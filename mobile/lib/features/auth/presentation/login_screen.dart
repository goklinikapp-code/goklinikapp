import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/auth_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_text_field.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref.read(authControllerProvider.notifier).login(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );
    if (!ok || !mounted) return;

    final biometricPromptDone =
        await ref.read(authStorageProvider).isBiometricPromptDone();
    if (!mounted) return;

    if (biometricPromptDone) {
      context.go('/home');
    } else {
      context.go('/biometric');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: GKColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Image.asset('assets/images/logo_go_klink.png', width: 140),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bem-vindo(a) de volta',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sua jornada de autocuidado continua aqui.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: GKColors.neutral),
                    ),
                    const SizedBox(height: 18),
                    GKTextField(
                      controller: _identifierController,
                      label: 'E-mail ou Número Fiscal',
                      prefixIcon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 12),
                    GKTextField(
                      controller: _passwordController,
                      label: 'Senha',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscure,
                      suffix: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Esqueci minha senha',
                            style: TextStyle(color: GKColors.primary)),
                      ),
                    ),
                    if (authState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(authState.errorMessage!,
                            style: const TextStyle(color: GKColors.danger)),
                      ),
                    GKButton(
                      label: 'Entrar',
                      onPressed: _submit,
                      isLoading: authState.loading,
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('OU CONTINUE COM',
                              style: TextStyle(
                                  fontSize: 11, color: GKColors.neutral)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GKButton(
                      label: 'Conta Google',
                      variant: GKButtonVariant.secondary,
                      icon: const Icon(Icons.g_mobiledata, size: 24),
                      onPressed: () {},
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Ainda não tem conta? '),
                        GestureDetector(
                          onTap: () => context.push('/register'),
                          child: const Text(
                            'Cadastre-se',
                            style: TextStyle(
                                color: GKColors.primary,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.help_outline,
                            size: 14, color: GKColors.neutral),
                        SizedBox(width: 4),
                        Text('Suporte',
                            style: TextStyle(
                                fontSize: 11, color: GKColors.neutral)),
                        SizedBox(width: 14),
                        Icon(Icons.shield_outlined,
                            size: 14, color: GKColors.neutral),
                        SizedBox(width: 4),
                        Text('Segurança',
                            style: TextStyle(
                                fontSize: 11, color: GKColors.neutral)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
