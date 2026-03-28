import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../data/patients_repository_impl.dart';
import '../domain/patient_models.dart';
import 'prontuario_manager_tab.dart';
import 'patients_controller.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  const PatientDetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patientState = ref.watch(patientDetailProvider(widget.patientId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhe do Paciente')),
      body: patientState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar paciente: $error')),
        data: (patient) {
          final statusVisual = _statusVisual(patient.medicStatus);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: GKCard(
                  child: Column(
                    children: [
                      GKAvatar(
                        name: patient.fullName,
                        imageUrl: patient.avatarUrl,
                        radius: 34,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        patient.fullName,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      GKBadge(
                        label: statusVisual.label,
                        background: statusVisual.background,
                        foreground: statusVisual.foreground,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            onPressed: _openChat,
                            icon: const Icon(Icons.chat_outlined),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () => _callPatient(patient.phone),
                            icon: const Icon(Icons.phone_outlined),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () => _openStatusSheet(patient),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Informacoes'),
                  Tab(text: 'Historico'),
                  Tab(text: 'Fotos'),
                  Tab(text: 'Documentos'),
                  Tab(text: 'Prontuario'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _infoTab(patient),
                    _historyTab(),
                    _photosTab(patient.id),
                    _documentsTab(),
                    ProntuarioManagerTab(patientId: patient.id),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoTab(MedicPatient patient) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GKCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Nome', patient.fullName),
              _row('Idade', patient.age?.toString() ?? '-'),
              _row('Telefone', patient.phone.isNotEmpty ? patient.phone : '-'),
              _row('E-mail', patient.email.isNotEmpty ? patient.email : '-'),
              _row('Tipo sanguineo',
                  patient.bloodType.isNotEmpty ? patient.bloodType : '-'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GKCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alergias',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (patient.allergies.isEmpty)
                const Text('Nenhuma alergia registrada')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: patient.allergies
                      .map(
                        (item) => GKBadge(
                          label: item,
                          background: const Color(0xFFFEE2E2),
                          foreground: const Color(0xFFB91C1C),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 14),
              const Text(
                'Medicamentos em uso',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (patient.currentMedications.isEmpty)
                const Text('Nenhum medicamento registrado')
              else
                ...patient.currentMedications.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.medication_outlined,
                            size: 16, color: GKColors.neutral),
                        const SizedBox(width: 6),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _historyTab() {
    final historyState = ref.watch(patientHistoryProvider(widget.patientId));
    return historyState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Erro ao carregar historico: $error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Sem historico registrado.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GKCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    item.description.isEmpty
                        ? 'Sem observacoes'
                        : item.description,
                    style: const TextStyle(color: GKColors.neutral),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.date == null ? '-' : formatDateTime(item.date!),
                    style:
                        const TextStyle(fontSize: 12, color: GKColors.neutral),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _photosTab(String patientId) {
    final journeyState = ref.watch(patientJourneyProvider(patientId));
    return journeyState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Erro ao carregar jornada: $error')),
      data: (journey) {
        if (journey == null) {
          return const Center(
            child: Text('Sem jornada ativa para este paciente.'),
          );
        }

        final photosState = ref.watch(journeyPhotosProvider(journey.id));
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Evolucao fotografica',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  GKButton(
                    label: _uploadingPhoto ? 'Enviando...' : 'Adicionar foto',
                    variant: GKButtonVariant.secondary,
                    onPressed:
                        _uploadingPhoto ? null : () => _addPhoto(journey.id),
                  ),
                ],
              ),
            ),
            Expanded(
              child: photosState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Erro ao carregar fotos: $error')),
                data: (photos) {
                  if (photos.isEmpty) {
                    return const Center(
                      child: Text('Sem fotos cadastradas para esta jornada.'),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return GKCard(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  photo.photoUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFE2E8F0),
                                    child: const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Dia ${photo.dayNumber}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _documentsTab() {
    final docsState = ref.watch(patientDocumentsProvider(widget.patientId));
    return docsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Erro ao carregar documentos: $error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Nenhum documento encontrado.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GKCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined,
                      color: GKColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.documentType} - ${item.uploadedAt == null ? '-' : formatDate(item.uploadedAt!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: GKColors.neutral,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openExternalUrl(item.fileUrl),
                    icon: const Icon(Icons.download_outlined),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openChat() async {
    if (!mounted) return;
    context.push('/chat');
  }

  Future<void> _callPatient(String phone) async {
    if (phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:${phone.trim()}');
    await launchUrl(uri);
  }

  Future<void> _openStatusSheet(MedicPatient patient) async {
    final selected = await showModalBottomSheet<MedicPatientStatus>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        final options = [
          (
            status: MedicPatientStatus.scheduled,
            label: 'Agendado',
            description: 'Paciente aguardando consulta/procedimento',
            color: const Color(0xFF1D4ED8),
          ),
          (
            status: MedicPatientStatus.preOp,
            label: 'Pre-op',
            description: 'Preparacao pre-operatoria em andamento',
            color: const Color(0xFFB45309),
          ),
          (
            status: MedicPatientStatus.recovering,
            label: 'Em recuperacao',
            description: 'Recuperacao pos-procedimento ativa',
            color: const Color(0xFFC2410C),
          ),
          (
            status: MedicPatientStatus.recovered,
            label: 'Recuperado',
            description: 'Recuperacao concluida',
            color: const Color(0xFF166534),
          ),
          (
            status: MedicPatientStatus.specialCase,
            label: 'Caso especial',
            description: 'Acompanhamento intensivo',
            color: const Color(0xFFB91C1C),
          ),
          (
            status: MedicPatientStatus.inactive,
            label: 'Inativo',
            description: 'Paciente sem acompanhamento ativo',
            color: const Color(0xFF4B5563),
          ),
        ];

        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final item = options[index];
              return ListTile(
                onTap: () => Navigator.of(context).pop(item.status),
                leading: CircleAvatar(
                  radius: 6,
                  backgroundColor: item.color,
                ),
                title: Text(item.label),
                subtitle: Text(item.description),
              );
            },
          ),
        );
      },
    );

    if (selected == null) return;
    await ref.read(patientsRepositoryProvider).updatePatientStatus(
          patientId: patient.id,
          status: selected,
          currentNotes: patient.notes,
        );
    ref.invalidate(patientDetailProvider(widget.patientId));
    ref.invalidate(myPatientsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Status atualizado')),
    );
  }

  Future<void> _addPhoto(String journeyId) async {
    final picker = ImagePicker();
    final selected = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (selected == null) return;

    final photos = await ref.read(journeyPhotosProvider(journeyId).future);
    final nextDayNumber = photos.fold<int>(
            0, (max, item) => item.dayNumber > max ? item.dayNumber : max) +
        1;

    setState(() => _uploadingPhoto = true);
    try {
      await ref.read(patientsRepositoryProvider).uploadJourneyPhoto(
            journeyId: journeyId,
            dayNumber: nextDayNumber,
            file: File(selected.path),
          );
      ref.invalidate(journeyPhotosProvider(journeyId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto enviada com sucesso')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    if (rawUrl.trim().isEmpty) return;
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: GKColors.neutral,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  _StatusVisual _statusVisual(MedicPatientStatus status) {
    return switch (status) {
      MedicPatientStatus.scheduled => const _StatusVisual(
          label: 'Agendado',
          background: Color(0xFFE4EDFF),
          foreground: Color(0xFF1D4ED8),
        ),
      MedicPatientStatus.preOp => const _StatusVisual(
          label: 'Pre-op',
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFFB45309),
        ),
      MedicPatientStatus.recovering => const _StatusVisual(
          label: 'Em recuperacao',
          background: Color(0xFFFFE5D0),
          foreground: Color(0xFFC2410C),
        ),
      MedicPatientStatus.recovered => const _StatusVisual(
          label: 'Recuperado',
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        ),
      MedicPatientStatus.specialCase => const _StatusVisual(
          label: 'Caso especial',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        ),
      MedicPatientStatus.inactive => const _StatusVisual(
          label: 'Inativo',
          background: Color(0xFFE5E7EB),
          foreground: Color(0xFF4B5563),
        ),
    };
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
