import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../domain/medical_record_models.dart';
import 'medical_records_controller.dart';

class MedicalRecordScreen extends ConsumerStatefulWidget {
  const MedicalRecordScreen({super.key});

  @override
  ConsumerState<MedicalRecordScreen> createState() => _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends ConsumerState<MedicalRecordScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        ref.invalidate(myMedicalRecordProvider);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openDocument(String url) async {
    if (url.trim().isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _maskedTaxNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '********';
    final lastFour = digits.substring(digits.length - 4);
    return '******$lastFour';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myMedicalRecordProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Prontuário Digital')),
      body: state.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            GKLoadingShimmer(height: 130),
            SizedBox(height: 10),
            GKLoadingShimmer(height: 100),
            SizedBox(height: 10),
            GKLoadingShimmer(height: 210),
          ],
        ),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar prontuário: $error')),
        data: (record) {
          final procedure =
              record.procedureHistory.isNotEmpty ? record.procedureHistory.first : null;
          final activeMeds = record.medications.where((item) => item.emUso).toList();
          final medsSubtitle = activeMeds.isEmpty
              ? 'Sem informações'
              : '${activeMeds.length} medicamento(s) em uso';

          return RefreshIndicator(
            onRefresh: () => ref.refresh(myMedicalRecordProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GKCard(
                  child: Column(
                    children: [
                      GKAvatar(
                        name: record.fullName,
                        imageUrl: record.avatarUrl.isNotEmpty ? record.avatarUrl : null,
                        radius: 32,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        record.fullName,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Número fiscal: ${_maskedTaxNumber(record.cpf)} • Nascimento: ${record.dateOfBirth}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Plano de saúde: ${record.healthInsurance.trim().isNotEmpty ? record.healthInsurance : 'Particular'}',
                        textAlign: TextAlign.center,
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
                      const Text(
                        'ALERTA CRÍTICO',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: GKColors.danger,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('Alergias e condições'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _allergyTags(record),
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
                      const Text(
                        'ÚLTIMO PROCEDIMENTO',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        procedure?.nomeProcedimento.isNotEmpty == true
                            ? procedure!.nomeProcedimento
                            : 'Sem procedimento concluído',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        procedure == null
                            ? '-'
                            : '${procedure.profissionalResponsavel} • ${formatDate(procedure.dataProcedimento ?? DateTime.now())}',
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
                      const Text(
                        'ACESSO RÁPIDO',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _quickAccessItem(
                        icon: Icons.medication_outlined,
                        title: 'Medicações em uso',
                        subtitle: medsSubtitle,
                        onTap: () => _tabController.animateTo(2),
                      ),
                      _quickAccessItem(
                        icon: Icons.history_edu_outlined,
                        title: 'Histórico de procedimentos',
                        subtitle: '${record.procedureHistory.length} itens',
                        onTap: () => _tabController.animateTo(0),
                      ),
                      _quickAccessItem(
                        icon: Icons.description_outlined,
                        title: 'Documentos digitais',
                        subtitle: '${record.documents.length} arquivos',
                        onTap: () => _tabController.animateTo(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Histórico'),
                    Tab(text: 'Documentos'),
                    Tab(text: 'Medicações'),
                  ],
                ),
                SizedBox(
                  height: 460,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _HistoryTab(items: record.procedureHistory),
                      _DocumentsTab(items: record.documents, onOpen: _openDocument),
                      _MedicationsTab(items: record.medications),
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

  List<Widget> _allergyTags(MedicalRecordSummary record) {
    final chunks = record.allergies
        .split(RegExp(r'[\n,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty && item.toLowerCase() != 'não informado')
        .toList();

    if (chunks.isEmpty) {
      return const [
        GKBadge(
          label: 'Nenhuma alergia registrada',
          background: Color(0xFFFCA5A5),
          foreground: Colors.white,
        ),
      ];
    }

    return chunks
        .map(
          (item) => GKBadge(
            label: item,
            background: const Color(0xFFDC2626),
            foreground: Colors.white,
          ),
        )
        .toList();
  }

  Widget _quickAccessItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: GKColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.items});

  final List<ProcedureHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Sem procedimentos cadastrados.'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nomeProcedimento,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                item.dataProcedimento == null
                    ? 'Data não informada'
                    : DateFormat('dd/MM/yyyy').format(item.dataProcedimento!),
              ),
              if (item.profissionalResponsavel.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Profissional: ${item.profissionalResponsavel}'),
              ],
              if (item.descricao.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.descricao),
              ],
              if (item.images.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: item.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, imageIndex) {
                      final image = item.images[imageIndex];
                      return GestureDetector(
                        onTap: () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => Dialog(
                              insetPadding: const EdgeInsets.all(16),
                              child: InteractiveViewer(
                                child: Image.network(image.imageUrl, fit: BoxFit.contain),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            image.imageUrl,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(width: 84, height: 84, color: GKColors.tealIce),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({
    required this.items,
    required this.onOpen,
  });

  final List<MedicalDocumentItem> items;
  final Future<void> Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Nenhum documento disponível.'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isImage = item.fileType.toLowerCase().contains('imagem');
        return ListTile(
          leading: Icon(
            isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
            color: GKColors.primary,
          ),
          title: Text(item.title),
          subtitle: Text(
            item.description.trim().isNotEmpty
                ? item.description
                : DateFormat('dd/MM/yyyy').format(item.createdAt),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new_outlined),
            onPressed: () => onOpen(item.fileUrl),
          ),
        );
      },
    );
  }
}

class _MedicationsTab extends StatelessWidget {
  const _MedicationsTab({required this.items});

  final List<MedicationItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Sem medicações registradas.'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: Icon(
            Icons.medication_outlined,
            color: item.emUso ? GKColors.secondary : GKColors.neutral,
          ),
          title: Text(item.nomeMedicamento),
          subtitle: Text(
            [
              if (item.dosagem.trim().isNotEmpty) item.dosagem.trim(),
              if (item.frequencia.trim().isNotEmpty) item.frequencia.trim(),
            ].join(' • '),
          ),
          trailing: GKBadge(
            label: item.emUso ? 'Em uso' : 'Inativo',
            background:
                item.emUso ? const Color(0xFFE8F7EF) : const Color(0xFFE2E8F0),
            foreground: item.emUso ? GKColors.secondary : GKColors.neutral,
          ),
        );
      },
    );
  }
}
