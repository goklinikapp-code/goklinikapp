import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../settings/app_preferences.dart';

const _navLabels = <String, List<String>>{
  'en': ['PATIENTS', 'PRE-OP', 'SCHEDULE', 'INBOX', 'PROFILE'],
  'pt': ['PACIENTES', 'PRÉ-OP', 'AGENDA', 'CAIXA', 'PERFIL'],
  'es': ['PACIENTES', 'PRE-OP', 'AGENDA', 'BANDEJA', 'PERFIL'],
  'de': ['PATIENTEN', 'PRÄ-OP', 'TERMINE', 'POSTFACH', 'PROFIL'],
  'ru': ['PACIENTY', 'PRE-OP', 'RASPISANIE', 'VHODYASHCHIE', 'PROFIL'],
  'tr': ['HASTALAR', 'PRE-OP', 'TAKVIM', 'GELEN KUTUSU', 'PROFIL'],
};

class GKBottomNav extends ConsumerWidget {
  const GKBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _routes = [
    '/patients',
    '/pre-operatory',
    '/schedule',
    '/chat',
    '/profile',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appPreferencesControllerProvider).language;
    final labels = _navLabels[language] ?? _navLabels['en']!;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) => context.go(_routes[index]),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.people_outline),
          selectedIcon: const Icon(Icons.people),
          label: labels[0],
        ),
        NavigationDestination(
          icon: const Icon(Icons.fact_check_outlined),
          selectedIcon: const Icon(Icons.fact_check),
          label: labels[1],
        ),
        NavigationDestination(
          icon: const Icon(Icons.calendar_month_outlined),
          selectedIcon: const Icon(Icons.calendar_month),
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
