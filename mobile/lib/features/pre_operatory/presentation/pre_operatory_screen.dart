import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../domain/pre_operatory_models.dart';
import 'pre_operatory_controller.dart';

class PreOperatoryScreen extends ConsumerStatefulWidget {
  const PreOperatoryScreen({super.key});

  @override
  ConsumerState<PreOperatoryScreen> createState() => _PreOperatoryScreenState();
}

class _PreOperatoryScreenState extends ConsumerState<PreOperatoryScreen> {
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _previousSurgeriesController = TextEditingController();
  final _diseasesController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  bool _smoking = false;
  bool _alcohol = false;
  bool _isSubmitting = false;
  bool _isEditMode = false;
  String? _boundRecordId;
  final List<String> _photoPaths = [];
  final List<String> _documentPaths = [];

  @override
  void dispose() {
    _allergiesController.dispose();
    _medicationsController.dispose();
    _previousSurgeriesController.dispose();
    _diseasesController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _bindRecord(PreOperatoryRecord record) {
    _boundRecordId = record.id;
    _isEditMode = false;
    _allergiesController.text = record.allergies;
    _medicationsController.text = record.medications;
    _previousSurgeriesController.text = record.previousSurgeries;
    _diseasesController.text = record.diseases;
    _heightController.text =
        record.height == null ? '' : record.height!.toString();
    _weightController.text =
        record.weight == null ? '' : record.weight!.toString();
    _smoking = record.smoking;
    _alcohol = record.alcohol;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_review':
        return 'Em análise';
      case 'approved':
        return 'Aprovado';
      case 'rejected':
        return 'Rejeitado';
      case 'pending':
      default:
        return 'Pendente';
    }
  }

  _StatusVisual _statusVisual(String status) {
    switch (status) {
      case 'in_review':
        return const _StatusVisual(
          label: 'Em análise',
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFFB45309),
        );
      case 'approved':
        return const _StatusVisual(
          label: 'Aprovado',
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case 'rejected':
        return const _StatusVisual(
          label: 'Rejeitado',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        );
      case 'pending':
      default:
        return const _StatusVisual(
          label: 'Pendente',
          background: Color(0xFFE2E8F0),
          foreground: Color(0xFF334155),
        );
    }
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final selected = await picker.pickMultiImage(imageQuality: 85);
    if (!mounted || selected.isEmpty) return;

    setState(() {
      for (final file in selected) {
        if (!_photoPaths.contains(file.path)) {
          _photoPaths.add(file.path);
        }
      }
    });
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    setState(() {
      for (final file in result.files) {
        final path = file.path;
        if (path == null || path.trim().isEmpty) continue;
        if (!_documentPaths.contains(path)) {
          _documentPaths.add(path);
        }
      }
    });
  }

  PreOperatoryUpsertPayload _buildPayload() {
    return PreOperatoryUpsertPayload(
      allergies: _allergiesController.text.trim(),
      medications: _medicationsController.text.trim(),
      previousSurgeries: _previousSurgeriesController.text.trim(),
      diseases: _diseasesController.text.trim(),
      smoking: _smoking,
      alcohol: _alcohol,
      height: double.tryParse(_heightController.text.trim()),
      weight: double.tryParse(_weightController.text.trim()),
      photoPaths: List<String>.from(_photoPaths),
      documentPaths: List<String>.from(_documentPaths),
    );
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(preOperatoryControllerProvider.notifier)
          .submit(_buildPayload());

      if (!mounted) return;
      setState(() {
        _photoPaths.clear();
        _documentPaths.clear();
        _isEditMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pré-operatório enviado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar agora: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildPhotoList(List<PreOperatoryFileItem> items) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fotos enviadas',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text(
              'Nenhum arquivo enviado ainda.',
              style: TextStyle(color: GKColors.neutral),
            )
          else
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return GestureDetector(
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          insetPadding: const EdgeInsets.all(16),
                          child: InteractiveViewer(
                            child: Image.network(
                              item.fileUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                width: 220,
                                height: 220,
                                child: Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        item.fileUrl,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 90,
                          height: 90,
                          color: GKColors.tealIce,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentList(List<PreOperatoryFileItem> items) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Documentos enviados',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text(
              'Nenhum arquivo enviado ainda.',
              style: TextStyle(color: GKColors.neutral),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return ActionChip(
                  label: Text('Documento ${index + 1}'),
                  onPressed: () => _openUrl(item.fileUrl),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(preOperatoryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pré-operatório'),
        actions: [
          IconButton(
            onPressed: _isSubmitting
                ? null
                : () =>
                    ref.read(preOperatoryControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: state.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            GKLoadingShimmer(height: 82),
            SizedBox(height: 10),
            GKLoadingShimmer(height: 420),
          ],
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Erro ao carregar pré-operatório: $error'),
                const SizedBox(height: 12),
                GKButton(
                  label: 'Tentar novamente',
                  onPressed: () =>
                      ref.read(preOperatoryControllerProvider.notifier).load(),
                ),
              ],
            ),
          ),
        ),
        data: (record) {
          if (record != null && _boundRecordId != record.id) {
            scheduleMicrotask(() {
              if (!mounted) return;
              setState(() => _bindRecord(record));
            });
          }

          final status = _statusVisual(record?.status ?? 'pending');
          final hasRecord = record != null;
          final canEdit = !hasRecord || _isEditMode;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GKCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Status da triagem',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GKBadge(
                      label: status.label,
                      background: status.background,
                      foreground: status.foreground,
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
                      'Dados clínicos',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _allergiesController,
                      readOnly: !canEdit,
                      enabled: canEdit,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Alergias',
                        hintText: 'Ex.: Dipirona, látex...',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _medicationsController,
                      readOnly: !canEdit,
                      enabled: canEdit,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Medicamentos em uso',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _previousSurgeriesController,
                      readOnly: !canEdit,
                      enabled: canEdit,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Cirurgias anteriores',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _diseasesController,
                      readOnly: !canEdit,
                      enabled: canEdit,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Doenças',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            readOnly: !canEdit,
                            enabled: canEdit,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Altura (m)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            readOnly: !canEdit,
                            enabled: canEdit,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Peso (kg)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      value: _smoking,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fuma'),
                      onChanged: canEdit
                          ? (value) => setState(() => _smoking = value)
                          : null,
                    ),
                    SwitchListTile.adaptive(
                      value: _alcohol,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Consome álcool'),
                      onChanged: canEdit
                          ? (value) => setState(() => _alcohol = value)
                          : null,
                    ),
                    if (!canEdit) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Dados enviados. Toque em "Editar informações" se quiser atualizar.',
                        style: TextStyle(color: GKColors.neutral),
                      ),
                    ],
                    if (canEdit) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Uploads',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GKButton(
                              label: 'Adicionar fotos',
                              variant: GKButtonVariant.secondary,
                              onPressed: _isSubmitting ? null : _pickPhotos,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GKButton(
                              label: 'Adicionar docs',
                              variant: GKButtonVariant.secondary,
                              onPressed: _isSubmitting ? null : _pickDocuments,
                            ),
                          ),
                        ],
                      ),
                      if (_photoPaths.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${_photoPaths.length} foto(s) selecionada(s)',
                          style: const TextStyle(color: GKColors.neutral),
                        ),
                      ],
                      if (_documentPaths.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_documentPaths.length} documento(s) selecionado(s)',
                          style: const TextStyle(color: GKColors.neutral),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                    if (!hasRecord)
                      GKButton(
                        label: _isSubmitting
                            ? 'Enviando...'
                            : 'Enviar pré-operatório',
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    if (hasRecord && !canEdit)
                      GKButton(
                        label: 'Editar informações',
                        variant: GKButtonVariant.secondary,
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _isEditMode = true),
                      ),
                    if (hasRecord && canEdit)
                      Row(
                        children: [
                          Expanded(
                            child: GKButton(
                              label: 'Cancelar',
                              variant: GKButtonVariant.secondary,
                              onPressed: _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _bindRecord(record);
                                        _photoPaths.clear();
                                        _documentPaths.clear();
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GKButton(
                              label: _isSubmitting ? 'Salvando...' : 'Salvar',
                              onPressed: _isSubmitting ? null : _submit,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (record != null) ...[
                const SizedBox(height: 10),
                _buildPhotoList(record.photos),
                const SizedBox(height: 10),
                _buildDocumentList(record.documents),
                const SizedBox(height: 16),
                Text(
                  'Status atual: ${_statusLabel(record.status)}',
                  style: const TextStyle(color: GKColors.neutral),
                ),
              ],
            ],
          );
        },
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
