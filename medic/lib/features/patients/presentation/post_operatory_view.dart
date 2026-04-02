import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../domain/patient_models.dart';
import 'patients_controller.dart';

class PostOperatoryView extends ConsumerWidget {
  const PostOperatoryView({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postOperatoryState =
        ref.watch(patientPostOperatoryProvider(patientId));

    return postOperatoryState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Erro ao carregar pos-operatorio: $error'),
      ),
      data: (record) {
        if (record == null) {
          return const Center(
            child: Text(
                'Nenhuma jornada pos-operatoria ativa para este paciente.'),
          );
        }

        final statusVisual = _journeyStatusVisual(record.status);
        final clinicalVisual = _clinicalStatusVisual(record.clinicalStatus);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GKCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pos-operatorio',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      GKBadge(
                        label: statusVisual.label,
                        background: statusVisual.background,
                        foreground: statusVisual.foreground,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Dia ${record.currentDay} de ${record.totalDays}',
                    style: const TextStyle(
                      color: GKColors.neutral,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GKBadge(
                    label: clinicalVisual.label,
                    background: clinicalVisual.background,
                    foreground: clinicalVisual.foreground,
                  ),
                ],
              ),
            ),
            if (record.requiresAttention) ...[
              const SizedBox(height: 10),
              GKCard(
                color: const Color(0xFFFEF2F2),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFECACA)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Paciente requer atencao',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _SummaryCard(record: record),
            const SizedBox(height: 10),
            _CheckinsCard(checkins: record.checkins),
            const SizedBox(height: 10),
            _PhotosCard(photos: record.photos),
            const SizedBox(height: 10),
            _ObservationsCard(observations: record.observations),
          ],
        );
      },
    );
  }

  _Visual _journeyStatusVisual(PostOperatoryJourneyStatus status) {
    switch (status) {
      case PostOperatoryJourneyStatus.active:
        return const _Visual(
          label: 'Em andamento',
          background: Color(0xFFE4EDFF),
          foreground: Color(0xFF1D4ED8),
        );
      case PostOperatoryJourneyStatus.completed:
        return const _Visual(
          label: 'Concluido',
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case PostOperatoryJourneyStatus.cancelled:
        return const _Visual(
          label: 'Cancelado',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        );
    }
  }

  _Visual _clinicalStatusVisual(PostOperatoryClinicalStatus status) {
    switch (status) {
      case PostOperatoryClinicalStatus.ok:
        return const _Visual(
          label: 'OK',
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case PostOperatoryClinicalStatus.delayed:
        return const _Visual(
          label: 'Atrasado',
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFF92400E),
        );
      case PostOperatoryClinicalStatus.risk:
        return const _Visual(
          label: 'Em risco',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.record});

  final PatientPostOperatoryRecord record;

  @override
  Widget build(BuildContext context) {
    final lastCheckin = record.lastCheckinDate == null
        ? 'Sem check-in'
        : formatDateTime(record.lastCheckinDate!);
    final lastPain = record.lastPainLevel?.toString() ?? '-';

    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _valueRow('Ultimo check-in', lastCheckin),
          _valueRow('Dor (ultimo)', lastPain),
          _valueRow(
            'Dias sem check-in',
            record.daysWithoutCheckin.toString(),
          ),
        ],
      ),
    );
  }

  Widget _valueRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: GKColors.neutral,
            ),
          ),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckinsCard extends StatelessWidget {
  const _CheckinsCard({required this.checkins});

  final List<PatientPostOperatoryCheckin> checkins;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Check-ins',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (checkins.isEmpty)
            const Text(
              'Nenhum check-in enviado.',
              style: TextStyle(color: GKColors.neutral),
            )
          else
            ...checkins.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dia ${item.day}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('Dor: ${item.painLevel}/10'),
                      Text(item.hasFever ? 'Febre: Sim' : 'Febre: Nao'),
                      if (item.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          formatDateTime(item.createdAt!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: GKColors.neutral,
                          ),
                        ),
                      ],
                      if (item.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.notes,
                          style: const TextStyle(color: GKColors.neutral),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.photos});

  final List<PatientPostOperatoryPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fotos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (photos.isEmpty)
            const Text(
              'Nenhuma foto enviada.',
              style: TextStyle(color: GKColors.neutral),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return GestureDetector(
                  onTap: () => _openFullscreenImage(context, photo.imageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      photo.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE2E8F0),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: GKColors.neutral,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openFullscreenImage(BuildContext context, String imageUrl) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 260,
                  height: 260,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObservationsCard extends StatelessWidget {
  const _ObservationsCard({required this.observations});

  final List<PatientPostOperatoryObservation> observations;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Observacoes',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (observations.isEmpty)
            const Text(
              'Sem observacoes registradas.',
              style: TextStyle(color: GKColors.neutral),
            )
          else
            ...observations.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dia ${item.day}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.notes.isEmpty ? '-' : item.notes,
                      style: const TextStyle(color: GKColors.neutral),
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

class _Visual {
  const _Visual({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}
