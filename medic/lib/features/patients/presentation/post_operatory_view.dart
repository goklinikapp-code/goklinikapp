import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_translations.dart';
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
    String t(String key) => _t(context, key);
    final postOperatoryState =
        ref.watch(patientPostOperatoryProvider(patientId));

    return postOperatoryState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('${t('postop_load_error_prefix')} $error'),
      ),
      data: (record) {
        if (record == null) {
          return Center(
            child: Text(t('postop_no_active_journey')),
          );
        }

        final statusVisual = _journeyStatusVisual(record.status, t);
        final clinicalVisual = _clinicalStatusVisual(record.clinicalStatus, t);

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
                          t('postop_title'),
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
                    t('postop_day_of_total')
                        .replaceAll('{day}', '${record.currentDay}')
                        .replaceAll('{total}', '${record.totalDays}'),
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
                  child: Text(
                    t('postop_patient_requires_attention'),
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

  _Visual _journeyStatusVisual(
    PostOperatoryJourneyStatus status,
    String Function(String key) t,
  ) {
    switch (status) {
      case PostOperatoryJourneyStatus.active:
        return _Visual(
          label: t('postop_status_in_progress'),
          background: Color(0xFFE4EDFF),
          foreground: Color(0xFF1D4ED8),
        );
      case PostOperatoryJourneyStatus.completed:
        return _Visual(
          label: t('postop_status_completed'),
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case PostOperatoryJourneyStatus.cancelled:
        return _Visual(
          label: t('postop_status_cancelled'),
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        );
    }
  }

  _Visual _clinicalStatusVisual(
    PostOperatoryClinicalStatus status,
    String Function(String key) t,
  ) {
    switch (status) {
      case PostOperatoryClinicalStatus.ok:
        return _Visual(
          label: t('status_ok'),
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case PostOperatoryClinicalStatus.delayed:
        return _Visual(
          label: t('postop_clinical_delayed'),
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFF92400E),
        );
      case PostOperatoryClinicalStatus.risk:
        return _Visual(
          label: t('postop_clinical_risk'),
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
    String t(String key) => _t(context, key);
    final lastCheckin = record.lastCheckinDate == null
        ? t('postop_no_checkin')
        : formatDateTime(record.lastCheckinDate!);
    final lastPain = record.lastPainLevel?.toString() ?? '-';

    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('postop_summary_title'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _valueRow(t('postop_last_checkin'), lastCheckin),
          _valueRow(t('postop_last_pain'), lastPain),
          _valueRow(
            t('postop_days_without_checkin'),
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
    String t(String key) => _t(context, key);
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('postop_checkins_title'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (checkins.isEmpty)
            Text(
              t('postop_no_checkins'),
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
                        '${t('postop_day_label')} ${item.day}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('${t('postop_pain')}: ${item.painLevel}/10'),
                      Text(
                        item.hasFever
                            ? '${t('postop_fever_label')}: ${t('yes')}'
                            : '${t('postop_fever_label')}: ${t('no')}',
                      ),
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
    String t(String key) => _t(context, key);
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('postop_recovery_photos'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (photos.isEmpty)
            Text(
              t('postop_no_photos_yet'),
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
    String t(String key) => _t(context, key);
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('postop_notes'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (observations.isEmpty)
            Text(
              t('postop_no_observations'),
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
                      '${t('postop_day_label')} ${item.day}',
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

String _t(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  return appTr(key: key, language: language);
}
