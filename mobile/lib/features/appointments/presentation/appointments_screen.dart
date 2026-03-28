import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/appointment_models.dart';
import 'appointments_controller.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  int _tab = 0;
  ProviderSubscription<AuthViewState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appointmentsControllerProvider.notifier).load();
    });

    _authSubscription = ref.listenManual<AuthViewState>(authControllerProvider,
        (previous, next) {
      final previousToken = previous?.session?.accessToken;
      final nextToken = next.session?.accessToken;

      if (next.isAuthenticated &&
          nextToken != null &&
          nextToken != previousToken) {
        ref.read(appointmentsControllerProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsState = ref.watch(appointmentsControllerProvider);
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);
    final colorScheme = Theme.of(context).colorScheme;
    final listBottomPadding = 24 + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('appointments_title')),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(appointmentsControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: _tabButton(
                          t('appointments_upcoming'), 0, colorScheme)),
                  Expanded(
                      child: _tabButton(
                          t('appointments_history'), 1, colorScheme)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: appointmentsState.when(
                loading: () => ListView.separated(
                  padding: EdgeInsets.only(bottom: listBottomPadding),
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, __) => const GKLoadingShimmer(height: 112),
                ),
                error: (error, _) => Center(
                  child: _buildErrorState(error, t),
                ),
                data: (items) {
                  final filtered = _filterByTab(items);

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(t('appointments_empty_tab')),
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.only(bottom: listBottomPadding),
                    children: [
                      ...filtered.map(
                          (item) => _appointmentCard(item, t, colorScheme)),
                      const SizedBox(height: 12),
                      _infoCard(
                        title: t('health_tip_title'),
                        description: t('health_tip_description'),
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      _infoCard(
                        title: t('reminder_title'),
                        description: t('reminder_description'),
                        color: colorScheme.secondary,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AppointmentItem> _filterByTab(List<AppointmentItem> items) {
    final now = DateTime.now();
    if (_tab == 0) {
      return items.where((item) => item.dateTime.isAfter(now)).toList();
    }
    return items.where((item) => !item.dateTime.isAfter(now)).toList();
  }

  Widget _appointmentCard(AppointmentItem item, String Function(String) t,
      ColorScheme colorScheme) {
    final specialtyLabel = _normalizeSpecialtyLabel(
      specialtyName: item.specialtyName,
      professionalRole: item.professionalRole,
      t: t,
    );

    final statusColor = switch (item.status) {
      'confirmed' => colorScheme.secondary,
      'pending' => colorScheme.tertiary,
      'cancelled' => colorScheme.error,
      _ => colorScheme.primary,
    };

    return GKCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              GKAvatar(
                  name: item.professionalName.isEmpty
                      ? t('clinic_team')
                      : item.professionalName,
                  imageUrl: item.professionalAvatarUrl.isEmpty
                      ? null
                      : item.professionalAvatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      specialtyLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.professionalName.isEmpty
                          ? t('clinic_team')
                          : item.professionalName,
                    ),
                  ],
                ),
              ),
              GKBadge(
                label: item.status.toUpperCase(),
                background: statusColor,
                foreground: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_month,
                  size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(formatDate(item.date)),
              const SizedBox(width: 14),
              Icon(Icons.schedule,
                  size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(item.time),
            ],
          ),
          if (item.clinicLocation.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.place_outlined,
                    size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.clinicLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _normalizeSpecialtyLabel({
    required String specialtyName,
    required String professionalRole,
    required String Function(String) t,
  }) {
    final roleBased = _roleLabelFromProfessionalRole(
      professionalRole: professionalRole,
      t: t,
    );
    if (roleBased.isNotEmpty) {
      return roleBased;
    }

    final normalized = specialtyName.trim();
    if (normalized.isEmpty) {
      return t('surgeon_role');
    }

    final lower = normalized.toLowerCase();
    if (lower == 'especialidade' || lower == 'specialty') {
      return t('surgeon_role');
    }

    return normalized;
  }

  String _roleLabelFromProfessionalRole({
    required String professionalRole,
    required String Function(String) t,
  }) {
    switch (professionalRole.trim().toLowerCase()) {
      case 'surgeon':
        return t('surgeon_role');
      case 'nurse':
        return t('nurse_role');
      case 'secretary':
        return t('secretary_role');
      case 'clinic_master':
        return t('clinic_master_role');
      case 'patient':
        return t('patient_role');
      default:
        return '';
    }
  }

  Widget _infoCard({
    required String title,
    required String description,
    required Color color,
  }) {
    return GKCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _tabButton(String title, int index, ColorScheme colorScheme) {
    final active = _tab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color:
                  active ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error, String Function(String) t) {
    final statusCode =
        error is DioException ? error.response?.statusCode : null;
    final isForbidden = statusCode == 403;
    final isUnauthorized =
        error is DioException && error.response?.statusCode == 401;

    if (isForbidden) {
      return Text(
        t('appointments_forbidden'),
        textAlign: TextAlign.center,
      );
    }

    if (isUnauthorized) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t('appointments_session_expired'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              ref.read(authControllerProvider.notifier).clearSessionState();
              if (!mounted) return;
              context.go('/login');
            },
            icon: const Icon(Icons.login),
            label: Text(t('go_to_login')),
          ),
        ],
      );
    }

    return Text(t('appointments_load_error'));
  }
}
