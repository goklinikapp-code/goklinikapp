import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    final state = ref.watch(myMedicalRecordProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Prontuário Digital')),
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
        error: (error, _) =>
            Center(child: Text('Erro ao carregar prontuário: $error')),
        data: (record) {
          final allergyList = _splitText(record.allergies);
          final procedure = record.procedureHistory.isNotEmpty
              ? record.procedureHistory.first
              : null;

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
                                'Número fiscal: ******** • Nascimento: ${record.dateOfBirth}'),
                            const SizedBox(height: 4),
                            Text(
                                'Plano de saúde: ${record.previousSurgeries.isEmpty ? 'Particular' : 'Ativo'}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GKCard(
                        color: const Color(0xFFFEE2E2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ALERTA CRÍTICO',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: GKColors.danger)),
                            const SizedBox(height: 6),
                            const Text('Alergias e Condições'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: allergyList.isEmpty
                                  ? const [
                                      GKBadge(
                                          label: 'Nenhuma alergia registrada',
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
                            const Text('ÚLTIMO PROCEDIMENTO',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(
                              procedure?.specialtyName.isNotEmpty == true
                                  ? procedure!.specialtyName
                                  : 'Sem procedimento concluído',
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
                            const Text('ACESSO RÁPIDO',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _quickAccessItem(Icons.medication_outlined,
                                'Medicações em Uso', record.currentMedications),
                            _quickAccessItem(
                                Icons.history_edu_outlined,
                                'Histórico de Procedimentos',
                                '${record.procedureHistory.length} itens'),
                            _quickAccessItem(
                                Icons.description_outlined,
                                'Documentos Digitais',
                                '${record.documents.length} arquivos'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const TabBar(
                        tabs: [
                          Tab(text: 'Histórico'),
                          Tab(text: 'Documentos'),
                          Tab(text: 'Medicações'),
                        ],
                      ),
                      SizedBox(
                        height: 420,
                        child: TabBarView(
                          children: [
                            _HistoryTab(items: record.procedureHistory),
                            _DocumentsTab(items: record.documents),
                            _MedicationsTab(text: record.currentMedications),
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

  Widget _quickAccessItem(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: GKColors.primary),
      title: Text(title),
      subtitle: Text(subtitle.isEmpty ? 'Sem informações' : subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.items});

  final List<ProcedureHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Sem procedimentos concluídos.'));
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
  const _DocumentsTab({required this.items});

  final List<MedicalDocumentItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Nenhum documento disponível.'));
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
              ? 'Validade: ${formatDate(item.validUntil!)}'
              : DateFormat('dd/MM/yyyy').format(item.createdAt)),
          trailing: IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Link do documento: ${item.fileUrl}')),
              );
            },
          ),
        );
      },
    );
  }
}

class _MedicationsTab extends StatelessWidget {
  const _MedicationsTab({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final chunks = text
        .split(RegExp(r'[\n,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (chunks.isEmpty) {
      return const Center(child: Text('Sem medicações em uso registradas.'));
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
