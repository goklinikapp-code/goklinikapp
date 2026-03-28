import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_button.dart';
import 'auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardingData(
      icon: Icons.calendar_month_rounded,
      title: 'Agende seus procedimentos',
      subtitle: 'Escolha especialidades e horários disponíveis de forma simples e rápida.',
    ),
    _OnboardingData(
      icon: Icons.checklist_rounded,
      title: 'Acompanhe seu pós-operatório',
      subtitle: 'Receba checklists diários, orientações personalizadas e acompanhe sua evolução.',
    ),
    _OnboardingData(
      icon: Icons.chat_bubble_rounded,
      title: 'Comunique-se com sua clínica',
      subtitle: 'Tire dúvidas, receba lembretes e mantenha contato direto com sua equipe de saúde.',
    ),
  ];

  Future<void> _finish() async {
    await ref.read(authControllerProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GKColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Pular', style: TextStyle(color: GKColors.neutral)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 72,
                          backgroundColor: GKColors.tealIce,
                          child: Icon(item.icon, size: 62, color: GKColors.primary),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: GKColors.neutral),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Center(
                child: SmoothPageIndicator(
                  controller: _controller,
                  count: _pages.length,
                  effect: const ExpandingDotsEffect(
                    dotWidth: 10,
                    dotHeight: 10,
                    activeDotColor: GKColors.primary,
                    dotColor: Color(0xFFCBD5E1),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GKButton(
                label: _page == _pages.length - 1 ? 'Começar' : 'Próximo',
                onPressed: () {
                  if (_page == _pages.length - 1) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;
}
