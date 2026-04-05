import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/presentation/appointments_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/patients/presentation/patient_detail_screen.dart';
import '../../features/patients/presentation/patients_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import 'app_shell.dart';

final _routerRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier<int>(0);
  ref.listen<AuthViewState>(authControllerProvider, (_, __) {
    notifier.value++;
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerRefresh = ref.watch(_routerRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: routerRefresh,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/patients',
            builder: (context, state) => const PatientsScreen(),
          ),
          GoRoute(
            path: '/patients/:id',
            builder: (context, state) => PatientDetailScreen(
              patientId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '/schedule',
            builder: (context, state) => const AppointmentsScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.uri.path;
      final isInitialized = authState.initialized;
      final isAuthenticated = authState.isAuthenticated;

      if (!isInitialized) {
        return location == '/' ? null : '/';
      }

      if (!isAuthenticated) {
        return location == '/login' ? null : '/login';
      }

      if (location == '/' || location == '/login') {
        return '/patients';
      }

      return null;
    },
  );
});
