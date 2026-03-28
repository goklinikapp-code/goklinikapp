import 'package:flutter/material.dart';

import '../widgets/gk_bottom_nav.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int get _index {
    if (location.startsWith('/agendas') || location.startsWith('/appointments')) return 1;
    if (location.startsWith('/postop')) return 2;
    if (location.startsWith('/chat')) return 3;
    if (location.startsWith('/profile') || location.startsWith('/financial') || location.startsWith('/medical-records')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: GKBottomNav(currentIndex: _index),
    );
  }
}
