import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_media_url.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../data/patients_repository_impl.dart';
import '../domain/patient_models.dart';
import 'post_operatory_view.dart';
import 'pre_operatory_view.dart';
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
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);
    final patientState = ref.watch(patientDetailProvider(widget.patientId));

    return Scaffold(
      appBar: AppBar(title: Text(t('patient_detail_title'))),
      body: patientState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
            child: Text('${t('patient_detail_load_error_prefix')}: $error')),
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
                tabs: [
                  Tab(text: t('patient_detail_tab_info')),
                  Tab(text: t('patient_detail_tab_history')),
                  Tab(text: t('patient_detail_tab_photos')),
                  Tab(text: t('patient_detail_tab_documents')),
                  Tab(text: t('patient_detail_tab_preop')),
                  Tab(text: t('patient_detail_tab_postop')),
                  Tab(text: t('patient_detail_tab_prontuario')),
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
                    PreOperatoryView(patientId: patient.id),
                    PostOperatoryView(patientId: patient.id),
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
    String t(String key) => _tr(key);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GKCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row(t('patient_detail_name'), patient.fullName),
              _row(t('patient_detail_age'), patient.age?.toString() ?? '-'),
              _row(
                t('profile_phone'),
                patient.phone.isNotEmpty ? patient.phone : '-',
              ),
              _row(
                t('patient_detail_email'),
                patient.email.isNotEmpty ? patient.email : '-',
              ),
              _row(t('patient_detail_blood_type'),
                  patient.bloodType.isNotEmpty ? patient.bloodType : '-'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GKCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('preop_allergies'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (patient.allergies.isEmpty)
                Text(t('patient_detail_no_allergies'))
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
              Text(
                t('preop_medications_in_use'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (patient.currentMedications.isEmpty)
                Text(t('patient_detail_no_medications'))
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
    String t(String key) => _tr(key);
    final historyState = ref.watch(patientHistoryProvider(widget.patientId));
    return historyState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
          child:
              Text('${t('patient_detail_history_load_error_prefix')}: $error')),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(t('patient_detail_no_history')));
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
                        ? t('patient_detail_no_notes')
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
    String t(String key) => _tr(key);
    final journeyState = ref.watch(patientJourneyProvider(patientId));
    return journeyState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
          child:
              Text('${t('patient_detail_journey_load_error_prefix')}: $error')),
      data: (journey) {
        if (journey == null) {
          return Center(
            child: Text(t('postop_no_active_journey')),
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
                      t('patient_detail_photo_evolution'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  GKButton(
                    label: _uploadingPhoto
                        ? t('chat_sending')
                        : t('patient_detail_add_photo'),
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
                error: (error, _) => Center(
                    child: Text(
                        '${t('patient_detail_photos_load_error_prefix')}: $error')),
                data: (photos) {
                  if (photos.isEmpty) {
                    return Center(
                      child: Text(t('patient_detail_no_photos')),
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
                              '${t('postop_day_label')} ${photo.dayNumber}',
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
    String t(String key) => _tr(key);
    final docsState = ref.watch(patientDocumentsProvider(widget.patientId));
    return docsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
          child: Text(
              '${t('patient_detail_documents_load_error_prefix')}: $error')),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(t('patient_detail_no_documents')));
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
    String t(String key) => _tr(key);
    final selected = await showModalBottomSheet<MedicPatientStatus>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        final options = [
          (
            status: MedicPatientStatus.scheduled,
            label: t('patients_filter_scheduled'),
            description: t('patient_detail_status_scheduled_desc'),
            color: const Color(0xFF1D4ED8),
          ),
          (
            status: MedicPatientStatus.preOp,
            label: t('quick_pre_operatory'),
            description: t('patient_detail_status_preop_desc'),
            color: const Color(0xFFB45309),
          ),
          (
            status: MedicPatientStatus.recovering,
            label: t('patients_filter_recovering'),
            description: t('patient_detail_status_recovering_desc'),
            color: const Color(0xFFC2410C),
          ),
          (
            status: MedicPatientStatus.recovered,
            label: t('patients_filter_recovered'),
            description: t('patient_detail_status_recovered_desc'),
            color: const Color(0xFF166534),
          ),
          (
            status: MedicPatientStatus.specialCase,
            label: t('patients_filter_special'),
            description: t('patient_detail_status_special_desc'),
            color: const Color(0xFFB91C1C),
          ),
          (
            status: MedicPatientStatus.inactive,
            label: t('patient_status_inactive'),
            description: t('patient_detail_status_inactive_desc'),
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
      SnackBar(content: Text(t('patient_detail_status_updated'))),
    );
  }

  Future<void> _addPhoto(String journeyId) async {
    String t(String key) => _tr(key);
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
        SnackBar(content: Text(t('postop_photo_upload_success'))),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    if (rawUrl.trim().isEmpty) return;
    final uri = Uri.tryParse(resolveApiMediaUrl(rawUrl));
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
    String t(String key) => _tr(key);
    return switch (status) {
      MedicPatientStatus.scheduled => _StatusVisual(
          label: t('patients_filter_scheduled'),
          background: Color(0xFFE4EDFF),
          foreground: Color(0xFF1D4ED8),
        ),
      MedicPatientStatus.preOp => _StatusVisual(
          label: t('quick_pre_operatory'),
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFFB45309),
        ),
      MedicPatientStatus.recovering => _StatusVisual(
          label: t('patients_filter_recovering'),
          background: Color(0xFFFFE5D0),
          foreground: Color(0xFFC2410C),
        ),
      MedicPatientStatus.recovered => _StatusVisual(
          label: t('patients_filter_recovered'),
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        ),
      MedicPatientStatus.specialCase => _StatusVisual(
          label: t('patients_filter_special'),
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        ),
      MedicPatientStatus.inactive => _StatusVisual(
          label: t('patient_status_inactive'),
          background: Color(0xFFE5E7EB),
          foreground: Color(0xFF4B5563),
        ),
    };
  }

  String _tr(String key, {bool watch = false}) {
    final language = watch
        ? ref.watch(appPreferencesControllerProvider).language
        : ref.read(appPreferencesControllerProvider).language;
    return appTr(key: key, language: language);
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
