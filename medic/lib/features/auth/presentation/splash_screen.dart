import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final authController = ref.read(authControllerProvider.notifier);
      await authController.init();
      await Future<void>.delayed(const Duration(milliseconds: 450));
    } catch (_) {
      ref.read(authControllerProvider.notifier).markInitializedFallback();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GKColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo_go_klink.png',
              width: 180,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.local_hospital,
                    size: 72, color: GKColors.primary);
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'GoKlinik Medic',
              style: TextStyle(
                color: GKColors.darkBackground,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ],
        ),
      ),
    );
  }
}
