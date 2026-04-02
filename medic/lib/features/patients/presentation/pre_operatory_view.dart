import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../domain/patient_models.dart';
import 'patients_controller.dart';

class PreOperatoryView extends ConsumerWidget {
  const PreOperatoryView({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preOperatoryState = ref.watch(patientPreOperatoryProvider(patientId));

    return preOperatoryState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Erro ao carregar pre-operatorio: $error'),
      ),
      data: (record) {
        if (record == null) {
          return const Center(
            child: Text('Nenhum pre-operatorio enviado pelo paciente.'),
          );
        }

        final statusVisual = _statusVisual(record.status);
        final statusMessage = _statusMessage(record.status);

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
                          'Pre-operatorio',
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
                  if (statusMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      statusMessage,
                      style: const TextStyle(color: GKColors.neutral),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ClinicalDataCard(record: record),
            const SizedBox(height: 10),
            _PhysicalDataCard(record: record),
            const SizedBox(height: 10),
            _HabitsCard(record: record),
            const SizedBox(height: 10),
            _PhotosCard(photos: record.photos),
            const SizedBox(height: 10),
            _DocumentsCard(documents: record.documents),
            const SizedBox(height: 10),
            _NotesCard(notes: record.notes),
          ],
        );
      },
    );
  }

  _StatusVisual _statusVisual(PreOperatoryStatus status) {
    switch (status) {
      case PreOperatoryStatus.pending:
        return const _StatusVisual(
          label: 'Pendente',
          background: Color(0xFFE2E8F0),
          foreground: Color(0xFF334155),
        );
      case PreOperatoryStatus.inReview:
        return const _StatusVisual(
          label: 'Em analise',
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFFB45309),
        );
      case PreOperatoryStatus.approved:
        return const _StatusVisual(
          label: 'Aprovado',
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case PreOperatoryStatus.rejected:
        return const _StatusVisual(
          label: 'Reprovado',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        );
    }
  }

  String? _statusMessage(PreOperatoryStatus status) {
    switch (status) {
      case PreOperatoryStatus.pending:
        return 'Aguardando analise da clinica';
      case PreOperatoryStatus.inReview:
        return 'Em analise pela clinica';
      case PreOperatoryStatus.approved:
        return null;
      case PreOperatoryStatus.rejected:
        return 'Pre-operatorio nao aprovado';
    }
  }
}

class _ClinicalDataCard extends StatelessWidget {
  const _ClinicalDataCard({required this.record});

  final PatientPreOperatoryRecord record;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dados clinicos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _valueRow('Alergias', record.allergies),
          _valueRow('Medicamentos em uso', record.medications),
          _valueRow('Cirurgias anteriores', record.previousSurgeries),
          _valueRow('Doencas', record.diseases),
        ],
      ),
    );
  }
}

class _PhysicalDataCard extends StatelessWidget {
  const _PhysicalDataCard({required this.record});

  final PatientPreOperatoryRecord record;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dados fisicos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _valueRow('Altura', _formatHeight(record.height)),
          _valueRow('Peso', _formatWeight(record.weight)),
        ],
      ),
    );
  }

  String _formatHeight(double? value) {
    if (value == null) return '-';
    return '${value.toStringAsFixed(2)} m';
  }

  String _formatWeight(double? value) {
    if (value == null) return '-';
    return '${value.toStringAsFixed(1)} kg';
  }
}

class _HabitsCard extends StatelessWidget {
  const _HabitsCard({required this.record});

  final PatientPreOperatoryRecord record;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Habitos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _switchRow('Fuma', record.smokes),
          _switchRow('Consome alcool', record.drinksAlcohol),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IgnorePointer(
            child: Switch(
              value: value,
              onChanged: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.photos});

  final List<PreOperatoryAttachmentItem> photos;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fotos enviadas',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (photos.isEmpty)
            const Text(
              'Nenhuma foto enviada',
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
                  onTap: () => _openFullscreenImage(context, photo.fileUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      photo.fileUrl,
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

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({required this.documents});

  final List<PreOperatoryAttachmentItem> documents;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Documentos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (documents.isEmpty)
            const Text(
              'Nenhum documento enviado',
              style: TextStyle(color: GKColors.neutral),
            )
          else
            ...documents.map(
              (doc) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      color: GKColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doc.fileUrl.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openExternalUrl(doc.fileUrl),
                      icon: const Icon(Icons.open_in_new_outlined),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Observacoes da clinica',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            notes.trim().isEmpty ? 'Sem observacoes da clinica.' : notes,
            style: const TextStyle(color: GKColors.neutral),
          ),
        ],
      ),
    );
  }
}

Widget _valueRow(String label, String value) {
  final normalized = value.trim().isEmpty ? '-' : value.trim();
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
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
        const SizedBox(height: 2),
        Text(
          normalized,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _StatusVisual {
  const _StatusVisual({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}
