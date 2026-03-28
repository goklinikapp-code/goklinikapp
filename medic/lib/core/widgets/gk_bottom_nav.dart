import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GKBottomNav extends StatelessWidget {
  const GKBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _routes = ['/patients', '/schedule', '/chat', '/profile'];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) => context.go(_routes[index]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'PACIENTES',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'AGENDA',
        ),
        NavigationDestination(
          icon: Icon(Icons.message_outlined),
          selectedIcon: Icon(Icons.message),
          label: 'CAIXA',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'PERFIL',
        ),
      ],
    );
  }
}
