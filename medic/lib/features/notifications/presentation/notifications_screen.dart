import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

    final today = state.items.where((n) => _isToday(n.createdAt)).toList();
    final older = state.items.where((n) => !_isToday(n.createdAt)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          TextButton(
            onPressed: () => ref
                .read(notificationsControllerProvider.notifier)
                .markAllAsRead(),
            child: const Text('Marcar tudo',
                style: TextStyle(color: GKColors.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Hoje', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 8),
              GKBadge(
                label: '${today.length} novas',
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
            const GKCard(child: Text('Nenhuma notificação nova hoje.'))
          else
            ...today.map((item) => _NotificationCard(item: item)),
          const SizedBox(height: 12),
          Text('Anteriores', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (older.isEmpty)
            const GKCard(child: Text('Sem notificações anteriores.'))
          else
            ...older
                .map((item) => _NotificationCard(item: item, compact: true)),
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
  const _NotificationCard({required this.item, this.compact = false});

  final GKNotification item;
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
                    label: 'Confirmar presença',
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
                    label: 'Remarcar',
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
              label: 'Ver checklist',
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
