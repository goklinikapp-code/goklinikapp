import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../domain/medical_record_models.dart';
import 'medical_records_controller.dart';

class MedicalRecordScreen extends ConsumerWidget {
  const MedicalRecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => _t(context, key);
    final state = ref.watch(myMedicalRecordProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('medical_record_title'))),
      body: state.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            GKLoadingShimmer(height: 120),
            SizedBox(height: 10),
            GKLoadingShimmer(height: 100),
            SizedBox(height: 10),
            GKLoadingShimmer(height: 180),
          ],
        ),
        error: (error, _) => Center(
          child: Text('${t('medical_record_load_error_prefix')}: $error'),
        ),
        data: (record) {
          final allergyList = _splitText(record.allergies);
          final procedure = record.procedureHistory.isNotEmpty
              ? record.procedureHistory.first
              : null;
          final healthPlanName = record.previousSurgeries.isEmpty
              ? t('medical_record_insurance_private')
              : t('medical_record_insurance_active');

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GKCard(
                        child: Column(
                          children: [
                            GKAvatar(name: record.fullName, radius: 32),
                            const SizedBox(height: 10),
                            Text(record.fullName,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              t('medical_record_tax_birth')
                                  .replaceAll('{tax_id}', '********')
                                  .replaceAll(
                                      '{birth_date}', record.dateOfBirth),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t('medical_record_insurance_line')
                                  .replaceAll('{plan}', healthPlanName),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GKCard(
                        color: const Color(0xFFFEE2E2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('medical_record_critical_alert'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: GKColors.danger)),
                            const SizedBox(height: 6),
                            Text(t('medical_record_allergies_conditions')),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: allergyList.isEmpty
                                  ? [
                                      GKBadge(
                                          label: t('medical_record_no_allergy'),
                                          background: Color(0xFFFCA5A5),
                                          foreground: Colors.white)
                                    ]
                                  : allergyList
                                      .map((item) => GKBadge(
                                          label: item,
                                          background: const Color(0xFFDC2626),
                                          foreground: Colors.white))
                                      .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GKCard(
                        color: GKColors.primary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('medical_record_last_procedure'),
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(
                              procedure?.specialtyName.isNotEmpty == true
                                  ? procedure!.specialtyName
                                  : t('medical_record_no_completed_procedure'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              procedure == null
                                  ? '-'
                                  : '${procedure.professionalName} • ${procedure.date} ${procedure.time}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GKCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('medical_record_quick_access'),
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _quickAccessItem(
                              icon: Icons.medication_outlined,
                              title: t('medical_record_current_medications'),
                              subtitle: record.currentMedications,
                              noInfoText: t('medical_record_no_info'),
                            ),
                            _quickAccessItem(
                              icon: Icons.history_edu_outlined,
                              title: t('medical_record_procedure_history'),
                              subtitle: t('medical_record_items_count')
                                  .replaceAll('{count}',
                                      '${record.procedureHistory.length}'),
                              noInfoText: t('medical_record_no_info'),
                            ),
                            _quickAccessItem(
                              icon: Icons.description_outlined,
                              title: t('medical_record_digital_documents'),
                              subtitle: t('medical_record_files_count')
                                  .replaceAll(
                                      '{count}', '${record.documents.length}'),
                              noInfoText: t('medical_record_no_info'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TabBar(
                        tabs: [
                          Tab(text: t('medical_record_tab_history')),
                          Tab(text: t('medical_record_tab_documents')),
                          Tab(text: t('medical_record_tab_medications')),
                        ],
                      ),
                      SizedBox(
                        height: 420,
                        child: TabBarView(
                          children: [
                            _HistoryTab(items: record.procedureHistory, t: t),
                            _DocumentsTab(items: record.documents, t: t),
                            _MedicationsTab(
                              text: record.currentMedications,
                              t: t,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static List<String> _splitText(String source) {
    final chunks = source.split(RegExp(r'[\n,;]'));
    return chunks
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Widget _quickAccessItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String noInfoText,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: GKColors.primary),
      title: Text(title),
      subtitle: Text(subtitle.isEmpty ? noInfoText : subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.items,
    required this.t,
  });

  final List<ProcedureHistoryItem> items;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(t('medical_record_no_completed_procedures')),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: const Icon(Icons.circle, size: 10, color: GKColors.primary),
          title:
              Text(item.specialtyName.isEmpty ? item.type : item.specialtyName),
          subtitle:
              Text('${item.professionalName} • ${item.date} ${item.time}'),
        );
      },
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({
    required this.items,
    required this.t,
  });

  final List<MedicalDocumentItem> items;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(t('medical_record_no_documents')));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf_outlined,
              color: GKColors.primary),
          title: Text(item.title),
          subtitle: Text(item.validUntil != null
              ? t('medical_record_valid_until')
                  .replaceAll('{date}', formatDate(item.validUntil!))
              : DateFormat('dd/MM/yyyy').format(item.createdAt)),
          trailing: IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    t('medical_record_document_link_prefix')
                        .replaceAll('{url}', item.fileUrl),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MedicationsTab extends StatelessWidget {
  const _MedicationsTab({
    required this.text,
    required this.t,
  });

  final String text;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    final chunks = text
        .split(RegExp(r'[\n,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (chunks.isEmpty) {
      return Center(child: Text(t('medical_record_no_medications')));
    }

    return ListView.builder(
      itemCount: chunks.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading:
              const Icon(Icons.medication_outlined, color: GKColors.secondary),
          title: Text(chunks[index]),
        );
      },
    );
  }
}

String _t(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  return appTr(key: key, language: language);
}
