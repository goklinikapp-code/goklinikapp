import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/network/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/referral_deep_link_controller.dart';
import 'features/branding/presentation/tenant_branding_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnv();
  await _initIntl();
  await _initFirebase();

  runApp(const ProviderScope(child: GoKlinikApp()));
}

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Running without a local .env file is allowed in development.
  }
}

Future<void> _initIntl() async {
  const locales = ['en_US', 'pt_BR', 'es_ES', 'de_DE', 'ru_RU', 'tr_TR'];
  for (final locale in locales) {
    await initializeDateFormatting(locale);
  }
  Intl.defaultLocale = 'en_US';
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase can be initialized later when google-services files are added.
  }
}

class GoKlinikApp extends ConsumerStatefulWidget {
  const GoKlinikApp({super.key});

  @override
  ConsumerState<GoKlinikApp> createState() => _GoKlinikAppState();
}

class _GoKlinikAppState extends ConsumerState<GoKlinikApp> {
  ProviderSubscription<AuthViewState>? _authSubscription;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(appPreferencesControllerProvider.notifier).initialize();
      await ref.read(pushNotificationServiceProvider).initialize();
      await _setupDeepLinks();
    });

    _authSubscription = ref.listenManual<AuthViewState>(authControllerProvider,
        (previous, next) async {
      await ref.read(tenantBrandingProvider.notifier).syncWithAuthState(next);
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        await ref
            .read(pushNotificationServiceProvider)
            .registerTokenIfAuthenticated();
      }
    });
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    _authSubscription?.close();
    super.dispose();
  }

  Future<void> _setupDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      _handleIncomingDeepLink(initialUri);
    } catch (_) {
      // Ignore malformed initial links in development.
    }

    _deepLinkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingDeepLink,
      onError: (_) {
        // Ignore stream errors caused by malformed incoming URLs.
      },
    );
  }

  void _handleIncomingDeepLink(Uri? uri) {
    if (uri == null) return;
    ref.read(referralDeepLinkProvider.notifier).registerIncomingUri(uri);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final preferences = ref.watch(appPreferencesControllerProvider);
    final tenantBranding = ref.watch(tenantBrandingProvider);

    return MaterialApp.router(
      title: 'GoKlinik',
      debugShowCheckedModeBanner: false,
      locale: Locale(preferences.language),
      theme: AppTheme.light(
        primaryColor: tenantBranding.primaryColor,
        secondaryColor: tenantBranding.secondaryColor,
        accentColor: tenantBranding.accentColor,
      ),
      darkTheme: AppTheme.dark(
        primaryColor: tenantBranding.primaryColor,
        secondaryColor: tenantBranding.secondaryColor,
        accentColor: tenantBranding.accentColor,
      ),
      themeMode: preferences.darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
