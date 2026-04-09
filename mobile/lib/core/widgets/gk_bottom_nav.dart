import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../settings/app_preferences.dart';

const _navLabels = <String, List<String>>{
  'en': ['HOME', 'SCHEDULE', 'POST-OP', 'CHAT', 'PROFILE'],
  'pt': ['HOME', 'AGENDAS', 'PÓS-OP', 'CHAT', 'PERFIL'],
  'es': ['INICIO', 'AGENDA', 'POS-OP', 'CHAT', 'PERFIL'],
  'de': ['START', 'TERMINE', 'POST-OP', 'CHAT', 'PROFIL'],
  'ru': ['GLAVNAYA', 'RASPISANIE', 'POS-OP', 'CHAT', 'PROFIL'],
  'tr': ['ANA', 'TAKVIM', 'POST-OP', 'CHAT', 'PROFIL'],
};

class GKBottomNav extends ConsumerWidget {
  const GKBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _routes = ['/home', '/agendas', '/postop', '/chat', '/profile'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appPreferencesControllerProvider).language;
    final labels = _navLabels[language] ?? _navLabels['en']!;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        context.go(_routes[index]);
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: labels[0],
        ),
        NavigationDestination(
          icon: const Icon(Icons.calendar_month_outlined),
          selectedIcon: const Icon(Icons.calendar_month),
          label: labels[1],
        ),
        NavigationDestination(
          icon: const Icon(Icons.health_and_safety_outlined),
          selectedIcon: const Icon(Icons.health_and_safety),
          label: labels[2],
        ),
        NavigationDestination(
          icon: const Icon(Icons.message_outlined),
          selectedIcon: const Icon(Icons.message),
          label: labels[3],
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: labels[4],
        ),
      ],
    );
  }
}
