import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../../../core/widgets/notification_bell_action.dart';
import '../../patients/data/patients_repository_impl.dart';
import '../../patients/domain/patient_models.dart';
import '../../patients/presentation/patients_controller.dart';

enum PreOperatoryFilterChip {
  pending,
  inReview,
  approved,
  rejected,
}

extension on PreOperatoryFilterChip {
  PreOperatoryStatus get status {
    switch (this) {
      case PreOperatoryFilterChip.pending:
        return PreOperatoryStatus.pending;
      case PreOperatoryFilterChip.inReview:
        return PreOperatoryStatus.inReview;
      case PreOperatoryFilterChip.approved:
        return PreOperatoryStatus.approved;
      case PreOperatoryFilterChip.rejected:
        return PreOperatoryStatus.rejected;
    }
  }
}

class PreOperatoryScreen extends ConsumerStatefulWidget {
  const PreOperatoryScreen({super.key});

  @override
  ConsumerState<PreOperatoryScreen> createState() => _PreOperatoryScreenState();
}

class _PreOperatoryScreenState extends ConsumerState<PreOperatoryScreen> {
  PreOperatoryFilterChip _filter = PreOperatoryFilterChip.pending;
  bool _detailsSheetOpen = false;

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);
    final recordsState =
        ref.watch(myPreOperatoryRecordsProvider(_filter.status));

    return Scaffold(
      appBar: AppBar(
        title: Text(t('preop_title')),
        actions: [
          const NotificationBellAction(),
          IconButton(
            onPressed: () =>
                ref.invalidate(myPreOperatoryRecordsProvider(_filter.status)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip(
                    t('preop_filter_pending'), PreOperatoryFilterChip.pending),
                _chip(
                  t('preop_filter_in_review'),
                  PreOperatoryFilterChip.inReview,
                ),
                _chip(
                  t('preop_filter_approved'),
                  PreOperatoryFilterChip.approved,
                ),
                _chip(
                  t('preop_filter_rejected'),
                  PreOperatoryFilterChip.rejected,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: recordsState.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const GKLoadingShimmer(height: 104),
              ),
              error: (error, _) => Center(
                child: Text('${t('preop_load_error_prefix')}: $error'),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      t('preop_empty_filter'),
                    ),
                  );
                }

                final ordered = [...items]..sort(
                    (a, b) {
                      final aTime = a.updatedAt ??
                          a.createdAt ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final bTime = b.updatedAt ??
                          b.createdAt ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return bTime.compareTo(aTime);
                    },
                  );

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ordered.length,
                  itemBuilder: (context, index) {
                    final item = ordered[index];
                    final statusVisual = _statusVisual(item.status, t);
                    final referenceDate = item.updatedAt ?? item.createdAt;

                    return GestureDetector(
                      onTap:
                          _detailsSheetOpen ? null : () => _openDetails(item),
                      child: GKCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GKAvatar(
                              name: item.patientName.isEmpty
                                  ? t('patient_default')
                                  : item.patientName,
                              imageUrl: item.patientAvatarUrl.isEmpty
                                  ? null
                                  : item.patientAvatarUrl,
                              radius: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.patientName.isEmpty
                                        ? t('preop_patient_without_name')
                                        : item.patientName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    referenceDate == null
                                        ? t('preop_sent_date_missing')
                                        : '${t('preop_updated_at')} ${formatDateTime(referenceDate)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: GKColors.neutral,
                                    ),
                                  ),
                                  if (item.notes.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      item.notes.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: GKColors.neutral,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GKBadge(
                              label: statusVisual.label,
                              background: statusVisual.background,
                              foreground: statusVisual.foreground,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetails(PatientPreOperatoryRecord record) async {
    if (_detailsSheetOpen) return;
    _detailsSheetOpen = true;
    final language = ref.read(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);
    final notesController = TextEditingController(text: record.notes);
    var isSubmitting = false;
    var didCloseSheet = false;

    try {
      final shouldOpenPatient = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final maxHeight = MediaQuery.of(sheetContext).size.height * 0.92;
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> submit({PreOperatoryStatus? status}) async {
                if (isSubmitting) return;
                setSheetState(() => isSubmitting = true);
                try {
                  await ref
                      .read(patientsRepositoryProvider)
                      .updatePreOperatoryRecord(
                        preOperatoryId: record.id,
                        status: status,
                        notes: notesController.text,
                      );
                  ref.invalidate(myPreOperatoryRecordsProvider(_filter.status));
                  ref.invalidate(myPatientsProvider);
                  if (record.patientId.isNotEmpty) {
                    ref.invalidate(
                        patientPreOperatoryProvider(record.patientId));
                    ref.invalidate(patientDetailProvider(record.patientId));
                  }
                  if (!mounted || !sheetContext.mounted) return;
                  didCloseSheet = true;
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        status == PreOperatoryStatus.approved
                            ? t('preop_approved_success')
                            : status == PreOperatoryStatus.rejected
                                ? t('preop_rejected_success')
                                : t('preop_notes_saved_success'),
                      ),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('${t('preop_update_error_prefix')}: $error'),
                    ),
                  );
                } finally {
                  if (!didCloseSheet && sheetContext.mounted) {
                    setSheetState(() => isSubmitting = false);
                  }
                }
              }

              final statusVisual = _statusVisual(record.status, t);
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).scaffoldBackgroundColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon:
                                  const Icon(Icons.arrow_back_ios_new_rounded),
                              tooltip: t('chat_close'),
                            ),
                            Expanded(
                              child: Text(
                                record.patientName.isEmpty
                                    ? t('preop_title')
                                    : '${t('preop_title')} - ${record.patientName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            GKBadge(
                              label: statusVisual.label,
                              background: statusVisual.background,
                              foreground: statusVisual.foreground,
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: t('chat_close'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _detailsGrid(record),
                              const SizedBox(height: 12),
                              if (record.photos.isNotEmpty) ...[
                                Text(
                                  t('preop_photos_sent'),
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 84,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemBuilder: (context, index) {
                                      final photo = record.photos[index];
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          photo.fileUrl,
                                          width: 84,
                                          height: 84,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            width: 84,
                                            height: 84,
                                            color: const Color(0xFFE2E8F0),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.broken_image_outlined,
                                              color: GKColors.neutral,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 8),
                                    itemCount: record.photos.length,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextField(
                                controller: notesController,
                                minLines: 3,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  labelText: t('preop_clinic_notes_label'),
                                  hintText: t('preop_clinic_notes_hint'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed:
                                      isSubmitting ? null : () => submit(),
                                  child: Text(
                                    isSubmitting
                                        ? t('saving')
                                        : t('preop_save_notes_button'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: isSubmitting
                                          ? null
                                          : () => submit(
                                              status:
                                                  PreOperatoryStatus.rejected),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFFB91C1C),
                                        side: const BorderSide(
                                            color: Color(0xFFEF4444)),
                                      ),
                                      child: Text(
                                        isSubmitting
                                            ? t('please_wait')
                                            : t('preop_filter_rejected'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: isSubmitting
                                          ? null
                                          : () => submit(
                                              status:
                                                  PreOperatoryStatus.approved),
                                      child: Text(
                                        isSubmitting
                                            ? t('please_wait')
                                            : t('preop_filter_approved'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (record.patientId.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(sheetContext).pop(true);
                                    },
                                    icon: const Icon(Icons.person_outline),
                                    label: Text(t('preop_open_full_patient')),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
      if (!mounted) return;
      if (shouldOpenPatient == true && record.patientId.isNotEmpty) {
        context.push('/patients/${record.patientId}');
      }
    } finally {
      _detailsSheetOpen = false;
    }
  }

  Widget _detailsGrid(PatientPreOperatoryRecord record) {
    final language = ref.read(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _detailTile(t('preop_allergies'), record.allergies)),
            const SizedBox(width: 8),
            Expanded(
                child: _detailTile(t('preop_medications'), record.medications)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _detailTile(
                t('preop_previous_surgeries'),
                record.previousSurgeries,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _detailTile(t('preop_diseases'), record.diseases)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _detailTile(
                t('preop_height'),
                record.height == null
                    ? '-'
                    : '${record.height!.toStringAsFixed(2)} m',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _detailTile(
                t('preop_weight'),
                record.weight == null
                    ? '-'
                    : '${record.weight!.toStringAsFixed(1)} kg',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _detailTile(
                t('preop_smokes'),
                record.smokes ? t('yes') : t('no'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _detailTile(
                t('preop_drinks_alcohol'),
                record.drinksAlcohol ? t('yes') : t('no'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detailTile(String label, String value) {
    return GKCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: GKColors.neutral,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? '-' : value.trim(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
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

  Widget _chip(String label, PreOperatoryFilterChip value) {
    final active = _filter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: GKColors.primary,
        backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
        labelStyle: TextStyle(
          color: active ? Colors.white : onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
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
