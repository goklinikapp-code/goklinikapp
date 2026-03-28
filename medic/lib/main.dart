import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/branding/presentation/tenant_branding_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnv();
  await _initIntl();
  await _initFirebase();

  runApp(const ProviderScope(child: GoKlinikMedicApp()));
}

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Running without local .env is allowed in development.
  }
}

Future<void> _initIntl() async {
  const locales = ['en_US', 'pt_BR', 'es_ES', 'de_DE', 'ru_RU', 'tr_TR'];
  for (final locale in locales) {
    await initializeDateFormatting(locale);
  }
  Intl.defaultLocale = 'pt_BR';
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase setup is optional in local development.
  }
}

class GoKlinikMedicApp extends ConsumerStatefulWidget {
  const GoKlinikMedicApp({super.key});

  @override
  ConsumerState<GoKlinikMedicApp> createState() => _GoKlinikMedicAppState();
}

class _GoKlinikMedicAppState extends ConsumerState<GoKlinikMedicApp> {
  ProviderSubscription<AuthViewState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<AuthViewState>(
      authControllerProvider,
      (previous, next) async {
        await ref.read(tenantBrandingProvider.notifier).syncWithAuthState(next);
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final tenantBranding = ref.watch(tenantBrandingProvider);

    return MaterialApp.router(
      title: 'GoKlinik Medic',
      debugShowCheckedModeBanner: false,
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
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
