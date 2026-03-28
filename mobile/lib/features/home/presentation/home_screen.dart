import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../branding/presentation/tenant_branding_controller.dart';
import '../../notifications/presentation/notifications_controller.dart';
import 'home_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeData = ref.watch(homeProvider);
    final notifications = ref.watch(notificationsControllerProvider);
    final tenantBranding = ref.watch(tenantBrandingProvider);
    final authState = ref.watch(authControllerProvider);
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeProvider);
        await ref.read(notificationsControllerProvider.notifier).load();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          homeData.when(
            loading: () => const GKLoadingShimmer(height: 84),
            error: (_, __) => Text(t('home_load_error')),
            data: (data) {
              final next = data.nextAppointments.isNotEmpty
                  ? data.nextAppointments.first
                  : null;
              final hasTenantLogo = (tenantBranding.logoUrl ?? '').isNotEmpty;
              final tenantNameFromSession =
                  authState.session?.user.tenant?.name.trim() ?? '';
              final currentUser = authState.session?.user;
              final avatarName =
                  (currentUser?.fullName.trim().isNotEmpty ?? false)
                      ? currentUser!.fullName
                      : data.userName;
              final avatarUrl = (currentUser?.avatarUrl ?? '').trim();
              final clinicName = tenantNameFromSession.isNotEmpty
                  ? tenantNameFromSession
                  : tenantBranding.name.trim().isNotEmpty
                      ? tenantBranding.name.trim()
                      : 'GoKlinik';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GKAvatar(
                        name: avatarName,
                        imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('welcome_back')),
                            Text(
                              '${t('hello')}, ${data.userName}!',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      if (hasTenantLogo)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: Image.network(
                              tenantBranding.logoUrl!,
                              key: ValueKey(tenantBranding.logoUrl),
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.local_hospital_rounded,
                                size: 22,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () => context.push('/notifications'),
                            icon: const Icon(Icons.notifications_none_rounded),
                          ),
                          if (notifications.unreadCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle),
                                child: Text(
                                  notifications.unreadCount.toString(),
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _HighlightCard(
                          title: t('next_appointment'),
                          subtitle: next != null
                              ? '${formatDate(next.date)} • ${next.time} • ${next.professionalName}'
                              : t('no_appointment_scheduled'),
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withValues(alpha: 0.82),
                            ],
                          ),
                          badge: t('next_appointment_badge'),
                          unitLabel: clinicName,
                        ),
                        const SizedBox(width: 12),
                        _HighlightCard(
                          title: t('postop_active'),
                          subtitle: t('postop_active_subtitle'),
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.secondary,
                              colorScheme.secondary.withValues(alpha: 0.82),
                            ],
                          ),
                          badge: t('postop_badge'),
                          unitLabel: clinicName,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(t('quick_actions'),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _QuickAction(
                  title: t('quick_my_appointments'),
                  icon: Icons.calendar_month,
                  onTap: () => context.go('/agendas')),
              _QuickAction(
                  title: t('quick_postop'),
                  icon: Icons.health_and_safety,
                  onTap: () => context.go('/postop')),
              _QuickAction(
                  title: t('quick_contact_clinic'),
                  icon: Icons.chat_bubble_outline,
                  onTap: () => context.go('/chat')),
              _QuickAction(
                  title: t('quick_refer_friends'),
                  icon: Icons.share,
                  onTap: () => context.push('/referrals')),
              _QuickAction(
                  title: t('quick_my_medical_record'),
                  icon: Icons.folder_open_outlined,
                  onTap: () => context.push('/medical-records')),
              _QuickAction(
                  title: t('quick_results'),
                  icon: Icons.trending_up,
                  onTap: () => context.push('/financial')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('recommended_for_you'),
                  style: Theme.of(context).textTheme.titleLarge),
              TextButton(onPressed: () {}, child: Text(t('see_all'))),
            ],
          ),
          GKCard(
            child: Row(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.secondary],
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 34),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GKBadge(
                          label: t('premium_treatment'),
                          background:
                              colorScheme.tertiary.withValues(alpha: 0.22),
                          foreground: colorScheme.tertiary),
                      const SizedBox(height: 8),
                      Text(t('structured_rhinoplasty'),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(t('personalized_plan')),
                      const SizedBox(height: 8),
                      GKButton(
                          label: t('quick_my_appointments'),
                          onPressed: () => context.go('/agendas')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(t('clinic_news'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _NewsCard(title: t('news_item_1'), date: '23 Mar 2026'),
                _NewsCard(title: t('news_item_2'), date: '18 Mar 2026'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.badge,
    required this.unitLabel,
  });

  final String title;
  final String subtitle;
  final Gradient gradient;
  final String badge;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.82,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GKBadge(
              label: badge,
              background: Colors.white24,
              foreground: Colors.white),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.local_hospital_outlined,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  unitLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.title, required this.icon, required this.onTap});

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: GKCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: colorScheme.primary, size: 20),
            ),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.title, required this.date});

  final String title;
  final String date;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(colors: [
                colorScheme.primary.withValues(alpha: 0.18),
                colorScheme.secondary.withValues(alpha: 0.18),
              ]),
            ),
            child: Center(
                child:
                    Icon(Icons.article_outlined, color: colorScheme.primary)),
          ),
          const SizedBox(height: 6),
          Text(date,
              style:
                  TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
