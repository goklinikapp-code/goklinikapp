import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../domain/notification_models.dart';
import 'notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    final today = state.items.where((n) => _isToday(n.createdAt)).toList();
    final older = state.items.where((n) => !_isToday(n.createdAt)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(t('notifications_title')),
        actions: [
          TextButton(
            onPressed: () => ref
                .read(notificationsControllerProvider.notifier)
                .markAllAsRead(),
            child: Text(
              t('notifications_mark_all'),
              style: const TextStyle(color: GKColors.primary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text(
                t('notifications_today'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(width: 8),
              GKBadge(
                label: '${today.length} ${t('notifications_new_count_suffix')}',
                background: GKColors.primary,
                foreground: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (state.loading && state.items.isEmpty)
            ...List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: GKLoadingShimmer(height: 94),
              ),
            )
          else if (today.isEmpty)
            GKCard(child: Text(t('notifications_today_empty')))
          else
            ...today.map(
              (item) => _NotificationCard(
                item: item,
                t: t,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            t('notifications_older'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (older.isEmpty)
            GKCard(child: Text(t('notifications_older_empty')))
          else
            ...older.map(
              (item) => _NotificationCard(
                item: item,
                compact: true,
                t: t,
              ),
            ),
        ],
      ),
    );
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({
    required this.item,
    required this.t,
    this.compact = false,
  });

  final GKNotification item;
  final String Function(String key) t;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = switch (item.type) {
      'appointment_reminder' => Icons.calendar_month_outlined,
      'postop_alert' => Icons.health_and_safety_outlined,
      'new_message' => Icons.chat_bubble_outline,
      _ => Icons.notifications_none,
    };

    return GKCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: GKColors.tealIce,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: GKColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(
                DateFormat('HH:mm').format(item.createdAt.toLocal()),
                style: const TextStyle(fontSize: 11, color: GKColors.neutral),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.body),
          if (!compact && item.type == 'appointment_reminder') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GKButton(
                    label: t('appointments_confirm_attendance'),
                    onPressed: () async {
                      await ref
                          .read(notificationsControllerProvider.notifier)
                          .markAsRead(item.id);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GKButton(
                    label: t('reschedule'),
                    variant: GKButtonVariant.secondary,
                    onPressed: () async {
                      await ref
                          .read(notificationsControllerProvider.notifier)
                          .markAsRead(item.id);
                    },
                  ),
                ),
              ],
            ),
          ] else if (!compact && item.type == 'postop_alert') ...[
            const SizedBox(height: 10),
            GKButton(
              label: t('notifications_view_checklist'),
              variant: GKButtonVariant.secondary,
              onPressed: () async {
                await ref
                    .read(notificationsControllerProvider.notifier)
                    .markAsRead(item.id);
              },
            ),
          ],
        ],
      ),
    );
  }
}
