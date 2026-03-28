import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../domain/postop_models.dart';
import 'postop_controller.dart';

class PostOpScreen extends ConsumerWidget {
  const PostOpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(postOpControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sua Recuperação'),
        actions: [
          IconButton(
            onPressed: () => ref.read(postOpControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipe de enfermagem será conectada neste botão.')),
        ),
        backgroundColor: GKColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.emergency),
        label: const Text('Dúvida urgente'),
      ),
      body: state.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => const GKLoadingShimmer(height: 94),
        ),
        error: (error, _) => Center(
          child: Text('Erro ao carregar pós-op: $error'),
        ),
        data: (journey) {
          if (journey == null) {
            return const Center(
              child: Text('Você ainda não possui jornada pós-operatória ativa.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Procedimento: ${journey.procedureName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text('Cirurgia em ${formatDate(journey.surgeryDate)} • Dia atual: D+${journey.currentDay}'),
              const SizedBox(height: 12),
              GKCard(
                child: Row(
                  children: [
                    Expanded(
                      child: GKButton(
                        label: 'Minha evolução',
                        variant: GKButtonVariant.secondary,
                        onPressed: () => context.push('/postop/evolution'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GKButton(
                        label: 'Central de cuidados',
                        variant: GKButtonVariant.primary,
                        onPressed: () => context.push('/postop/care-center/${journey.id}'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...journey.protocol.map((day) => _TimelineDayCard(day: day, journeyId: journey.id)),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineDayCard extends ConsumerWidget {
  const _TimelineDayCard({required this.day, required this.journeyId});

  final JourneyProtocolDay day;
  final String journeyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = day.status == 'today';
    final isCompleted = day.status == 'completed';

    final indicatorColor = isCompleted
        ? GKColors.secondary
        : isToday
            ? GKColors.primary
            : const Color(0xFFCBD5E1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: isToday ? 18 : 14,
                height: isToday ? 18 : 14,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 10)
                    : null,
              ),
              Container(width: 2, height: 84, color: const Color(0xFFE2E8F0)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GKCard(
              color: isToday ? const Color(0xFFFFF8E8) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'DIA ${day.dayNumber}',
                        style: const TextStyle(
                          color: GKColors.neutral,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isToday)
                        const GKBadge(
                          label: 'HOJE',
                          background: Color(0xFFFFE6B0),
                          foreground: GKColors.accent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(day.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(day.description),
                  const SizedBox(height: 8),
                  ...day.checklistItems.map(
                    (item) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: item.isCompleted,
                      title: Text(item.itemText, style: const TextStyle(fontSize: 13)),
                      onChanged: item.isCompleted
                          ? null
                          : (_) async {
                              await ref.read(postOpControllerProvider.notifier).completeChecklist(item.id);
                            },
                    ),
                  ),
                  if (day.isMilestone)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: GKButton(
                        label: 'Confirmar retorno',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Retorno confirmado para a equipe clínica.')),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
