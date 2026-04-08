import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/presentation/appointments_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/biometric_prompt_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/referral_deep_link_controller.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_room_screen.dart';
import '../../features/financial/presentation/financial_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/medical_records/presentation/medical_record_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/post_op/presentation/care_center_screen.dart';
import '../../features/post_op/presentation/evolution_screen.dart';
import '../../features/post_op/presentation/postop_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/notification_preferences_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/pre_operatory/presentation/pre_operatory_screen.dart';
import '../../features/referrals/presentation/referrals_screen.dart';
import '../../features/travel_plans/presentation/travel_plan_screen.dart';
import 'app_shell.dart';

final _routerRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier<int>(0);
  ref.listen<AuthViewState>(authControllerProvider, (_, __) {
    notifier.value++;
  });
  ref.listen<ReferralDeepLinkState>(referralDeepLinkProvider, (_, __) {
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
    debugLogDiagnostics: true,
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro de navegação')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('O aplicativo encontrou um problema de rota.'),
              const SizedBox(height: 8),
              Text(state.error?.toString() ?? 'Erro desconhecido'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
          path: '/biometric',
          builder: (context, state) => const BiometricPromptScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
              path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(
              path: '/agendas',
              builder: (context, state) => const AppointmentsScreen()),
          GoRoute(
              path: '/appointments/new/step1', redirect: (_, __) => '/agendas'),
          GoRoute(
              path: '/appointments/new/step2', redirect: (_, __) => '/agendas'),
          GoRoute(
              path: '/appointments/new/step3', redirect: (_, __) => '/agendas'),
          GoRoute(
              path: '/postop',
              builder: (context, state) => const PostOpScreen()),
          GoRoute(
              path: '/postop/evolution',
              builder: (context, state) => const EvolutionScreen()),
          GoRoute(
            path: '/postop/care-center/:journeyId',
            builder: (context, state) => CareCenterScreen(
                journeyId: state.pathParameters['journeyId'] ?? ''),
          ),
          GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatListScreen()),
          GoRoute(
            path: '/chat/room/:roomId',
            builder: (context, state) =>
                ChatRoomScreen(roomId: state.pathParameters['roomId'] ?? ''),
          ),
          GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsScreen()),
          GoRoute(
              path: '/financial',
              builder: (context, state) => const FinancialScreen()),
          GoRoute(
              path: '/pre-operatory',
              builder: (context, state) => const PreOperatoryScreen()),
          GoRoute(
              path: '/referrals',
              builder: (context, state) => const ReferralsScreen()),
          GoRoute(
              path: '/medical-records',
              builder: (context, state) => const MedicalRecordScreen()),
          GoRoute(
              path: '/travel-plan',
              builder: (context, state) => const TravelPlanScreen()),
          GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen()),
          GoRoute(
              path: '/profile/edit',
              builder: (context, state) => const EditProfileScreen()),
          GoRoute(
            path: '/profile/notification-preferences',
            builder: (context, state) => const NotificationPreferencesScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.uri.path;
      final isInitialized = authState.initialized;
      final isAuthenticated = authState.isAuthenticated;
      final onboardingDone = authState.onboardingCompleted;
      final pendingReferralCode =
          ref.read(referralDeepLinkProvider).pendingCode;
      final authRoutes = {'/login', '/register', '/biometric'};

      // 1) Wait for bootstrap on splash.
      if (!isInitialized) {
        return location == '/' ? null : '/';
      }

      // Deep link flow must open register directly for non-authenticated users.
      if (!isAuthenticated &&
          pendingReferralCode != null &&
          pendingReferralCode.isNotEmpty) {
        return location == '/register' ? null : '/register';
      }

      // 2) Onboarding is mandatory before auth flow.
      if (!onboardingDone) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      // 3) Onboarding done but user not authenticated.
      if (!isAuthenticated) {
        if (location == '/' || location == '/onboarding') return '/login';
        return authRoutes.contains(location) ? null : '/login';
      }

      // 4) Authenticated area.
      if (location == '/' ||
          location == '/onboarding' ||
          location == '/login' ||
          location == '/register' ||
          location == '/biometric') {
        return '/home';
      }

      return null;
    },
  );
});
