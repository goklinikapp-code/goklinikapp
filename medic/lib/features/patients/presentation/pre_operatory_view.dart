import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/settings/app_translations.dart';
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
    String t(String key) => _t(context, key);

    return preOperatoryState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('${t('preop_load_error_prefix')}: $error'),
      ),
      data: (record) {
        if (record == null) {
          return Center(
            child: Text(t('preop_patient_empty')),
          );
        }

        final statusVisual = _statusVisual(record.status, t);
        final statusMessage = _statusMessage(record.status, t);

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
                          t('preop_title'),
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
            _ClinicalDataCard(record: record, t: t),
            const SizedBox(height: 10),
            _PhysicalDataCard(record: record, t: t),
            const SizedBox(height: 10),
            _HabitsCard(record: record, t: t),
            const SizedBox(height: 10),
            _PhotosCard(photos: record.photos, t: t),
            const SizedBox(height: 10),
            _DocumentsCard(documents: record.documents, t: t),
            const SizedBox(height: 10),
            _NotesCard(notes: record.notes, t: t),
          ],
        );
      },
    );
  }

  _StatusVisual _statusVisual(
    PreOperatoryStatus status,
    String Function(String key) t,
  ) {
    switch (status) {
      case PreOperatoryStatus.pending:
        return _StatusVisual(
          label: t('preop_status_pending'),
          background: Color(0xFFE2E8F0),
          foreground: Color(0xFF334155),
        );
      case PreOperatoryStatus.inReview:
        return _StatusVisual(
          label: t('preop_status_in_review'),
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFFB45309),
        );
      case PreOperatoryStatus.approved:
        return _StatusVisual(
          label: t('preop_status_approved'),
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case PreOperatoryStatus.rejected:
        return _StatusVisual(
          label: t('preop_status_rejected'),
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        );
    }
  }

  String? _statusMessage(
    PreOperatoryStatus status,
    String Function(String key) t,
  ) {
    switch (status) {
      case PreOperatoryStatus.pending:
        return t('preop_status_message_pending');
      case PreOperatoryStatus.inReview:
        return t('preop_status_message_in_review');
      case PreOperatoryStatus.approved:
        return null;
      case PreOperatoryStatus.rejected:
        return t('preop_status_message_rejected');
    }
  }
}

class _ClinicalDataCard extends StatelessWidget {
  const _ClinicalDataCard({
    required this.record,
    required this.t,
  });

  final PatientPreOperatoryRecord record;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('preop_clinical_data_title'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _valueRow(t('preop_allergies'), record.allergies),
          _valueRow(t('preop_medications_in_use'), record.medications),
          _valueRow(t('preop_previous_surgeries'), record.previousSurgeries),
          _valueRow(t('preop_diseases'), record.diseases),
        ],
      ),
    );
  }
}

class _PhysicalDataCard extends StatelessWidget {
  const _PhysicalDataCard({
    required this.record,
    required this.t,
  });

  final PatientPreOperatoryRecord record;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('preop_physical_data_title'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _valueRow(t('preop_height'), _formatHeight(record.height)),
          _valueRow(t('preop_weight'), _formatWeight(record.weight)),
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
  const _HabitsCard({
    required this.record,
    required this.t,
  });

  final PatientPreOperatoryRecord record;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('preop_habits_title'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _switchRow(t('preop_smokes'), record.smokes),
          _switchRow(t('preop_drinks_alcohol'), record.drinksAlcohol),
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
  const _PhotosCard({
    required this.photos,
    required this.t,
  });

  final List<PreOperatoryAttachmentItem> photos;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('preop_photos_sent'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (photos.isEmpty)
            Text(
              t('preop_no_photos_sent'),
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
  const _DocumentsCard({
    required this.documents,
    required this.t,
  });

  final List<PreOperatoryAttachmentItem> documents;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('preop_documents_title'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (documents.isEmpty)
            Text(
              t('preop_no_documents_sent'),
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
  const _NotesCard({
    required this.notes,
    required this.t,
  });

  final String notes;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('preop_clinic_notes_label'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            notes.trim().isEmpty ? t('preop_no_clinic_notes') : notes,
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

String _t(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  return appTr(key: key, language: language);
}
