import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../data/patients_repository_impl.dart';
import '../domain/patient_models.dart';
import 'patients_controller.dart';

class ProntuarioManagerTab extends ConsumerWidget {
  const ProntuarioManagerTab({
    super.key,
    required this.patientId,
  });

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicationsState =
        ref.watch(patientProntuarioMedicationsProvider(patientId));
    final proceduresState =
        ref.watch(patientProntuarioProceduresProvider(patientId));
    final documentsState =
        ref.watch(patientProntuarioDocumentsProvider(patientId));

    final medications =
        medicationsState.valueOrNull ?? const <ProntuarioMedicationItem>[];
    final activeMeds = medications.where((item) => item.emUso).length;
    final procedures =
        proceduresState.valueOrNull ?? const <ProntuarioProcedureItem>[];
    final documents =
        documentsState.valueOrNull ?? const <ProntuarioDocumentItem>[];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        GKCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gestão de prontuário',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _summaryChip('Medicações ativas', '$activeMeds'),
                  _summaryChip('Procedimentos', '${procedures.length}'),
                  _summaryChip('Documentos', '${documents.length}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _MedicationsCard(
          state: medicationsState,
          onAdd: () => _openMedicationForm(context, ref),
          onEdit: (item) => _openMedicationForm(context, ref, item: item),
          onDeactivate: (item) => _deactivateMedication(context, ref, item),
        ),
        const SizedBox(height: 10),
        _ProceduresCard(
          state: proceduresState,
          onAdd: () => _openProcedureForm(context, ref),
          onEdit: (item) => _openProcedureForm(context, ref, item: item),
          onDelete: (item) => _deleteProcedure(context, ref, item),
          onOpenImage: (url) => _openExternalUrl(url),
        ),
        const SizedBox(height: 10),
        _DocumentsCard(
          state: documentsState,
          onAdd: () => _openDocumentForm(context, ref),
          onEdit: (item) => _openDocumentForm(context, ref, item: item),
          onDelete: (item) => _deleteDocument(context, ref, item),
          onOpenDocument: (url) => _openExternalUrl(url),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: GKColors.neutral,
        ),
      ),
    );
  }

  Future<void> _refreshAll(WidgetRef ref) async {
    ref.invalidate(patientProntuarioMedicationsProvider(patientId));
    ref.invalidate(patientProntuarioProceduresProvider(patientId));
    ref.invalidate(patientProntuarioDocumentsProvider(patientId));
  }

  Future<void> _openMedicationForm(
    BuildContext context,
    WidgetRef ref, {
    ProntuarioMedicationItem? item,
  }) async {
    final nameController =
        TextEditingController(text: item?.nomeMedicamento ?? '');
    final dosageController = TextEditingController(text: item?.dosagem ?? '');
    final frequencyController =
        TextEditingController(text: item?.frequencia ?? '');
    final routeController =
        TextEditingController(text: item?.viaAdministracao ?? '');
    final startDateController = TextEditingController(
      text: _toDateInput(item?.dataInicio ?? DateTime.now()),
    );
    final endDateController = TextEditingController(
      text: item?.dataFim != null ? _toDateInput(item!.dataFim!) : '',
    );
    final descriptionController =
        TextEditingController(text: item?.descricao ?? '');
    var emUso = item?.emUso ?? true;
    var possuiAlergia = item?.possuiAlergia ?? false;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> pickDate(TextEditingController controller) async {
              final initialDate =
                  DateTime.tryParse(controller.text) ?? DateTime.now();
              final picked = await showDatePicker(
                context: modalContext,
                initialDate: initialDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) {
                setModalState(() {
                  controller.text = _toDateInput(picked);
                });
              }
            }

            Future<void> save() async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  const SnackBar(
                      content: Text('Informe o nome do medicamento.')),
                );
                return;
              }
              if (startDateController.text.trim().isEmpty) {
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  const SnackBar(content: Text('Informe a data de início.')),
                );
                return;
              }

              final payload = <String, dynamic>{
                'nome_medicamento': nameController.text.trim(),
                'dosagem': dosageController.text.trim(),
                'frequencia': frequencyController.text.trim(),
                'via_administracao': routeController.text.trim(),
                'data_inicio': startDateController.text.trim(),
                'em_uso': emUso,
                'possui_alergia': possuiAlergia,
                'descricao': descriptionController.text.trim(),
              };
              if (endDateController.text.trim().isNotEmpty) {
                payload['data_fim'] = endDateController.text.trim();
              }

              setModalState(() => saving = true);
              try {
                if (item == null) {
                  await ref
                      .read(patientsRepositoryProvider)
                      .createPatientProntuarioMedication(
                        patientId: patientId,
                        payload: payload,
                      );
                } else {
                  await ref
                      .read(patientsRepositoryProvider)
                      .updatePatientProntuarioMedication(
                        patientId: patientId,
                        medicationId: item.id,
                        payload: payload,
                      );
                }
                await _refreshAll(ref);
                if (!modalContext.mounted) return;
                Navigator.of(modalContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(item == null
                        ? 'Medicamento salvo com sucesso.'
                        : 'Medicamento atualizado com sucesso.'),
                  ),
                );
              } catch (error) {
                if (!modalContext.mounted) return;
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  SnackBar(
                      content: Text('Falha ao salvar medicamento: $error')),
                );
              } finally {
                if (modalContext.mounted) {
                  setModalState(() => saving = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(modalContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item == null
                            ? 'Adicionar medicação'
                            : 'Editar medicação',
                        style: Theme.of(modalContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                            labelText: 'Nome do medicamento'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: dosageController,
                        decoration: const InputDecoration(labelText: 'Dosagem'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: frequencyController,
                        decoration:
                            const InputDecoration(labelText: 'Frequência'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: routeController,
                        decoration: const InputDecoration(
                            labelText: 'Via de administração'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: startDateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Data de início',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: () => pickDate(startDateController),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: endDateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Data final (opcional)',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: () => pickDate(endDateController),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: emUso,
                        onChanged: (value) =>
                            setModalState(() => emUso = value),
                        title: const Text('Em uso'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: possuiAlergia,
                        onChanged: (value) =>
                            setModalState(() => possuiAlergia = value),
                        title: const Text('Possui alergia'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Descrição'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GKButton(
                              label: 'Cancelar',
                              variant: GKButtonVariant.secondary,
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(modalContext).pop(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GKButton(
                              label: saving ? 'Salvando...' : 'Salvar',
                              onPressed: saving ? null : save,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deactivateMedication(
    BuildContext context,
    WidgetRef ref,
    ProntuarioMedicationItem item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desativar medicação'),
        content: Text('Deseja desativar "${item.nomeMedicamento}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref
          .read(patientsRepositoryProvider)
          .deactivatePatientProntuarioMedication(
            patientId: patientId,
            medicationId: item.id,
          );
      await _refreshAll(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicação desativada.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao desativar medicação: $error')),
      );
    }
  }

  Future<void> _openProcedureForm(
    BuildContext context,
    WidgetRef ref, {
    ProntuarioProcedureItem? item,
  }) async {
    final nameController =
        TextEditingController(text: item?.nomeProcedimento ?? '');
    final dateController = TextEditingController(
      text: _toDateInput(item?.dataProcedimento ?? DateTime.now()),
    );
    final professionalController =
        TextEditingController(text: item?.profissionalResponsavel ?? '');
    final descriptionController =
        TextEditingController(text: item?.descricao ?? '');
    final notesController =
        TextEditingController(text: item?.observacoes ?? '');
    final selectedFiles = <File>[];
    final existingImages = List<ProntuarioProcedureImageItem>.from(
      item?.images ?? const <ProntuarioProcedureImageItem>[],
    );
    final deletingImageIds = <String>{};
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> pickDate() async {
              final initialDate =
                  DateTime.tryParse(dateController.text) ?? DateTime.now();
              final picked = await showDatePicker(
                context: modalContext,
                initialDate: initialDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) {
                setModalState(() {
                  dateController.text = _toDateInput(picked);
                });
              }
            }

            Future<void> pickImages() async {
              final picker = ImagePicker();
              final picks = await picker.pickMultiImage(imageQuality: 85);
              if (picks.isEmpty) return;
              setModalState(() {
                selectedFiles.addAll(picks.map((file) => File(file.path)));
              });
            }

            Future<void> deleteSavedImage(
              ProntuarioProcedureImageItem image,
            ) async {
              if (item == null || deletingImageIds.contains(image.id)) return;
              setModalState(() => deletingImageIds.add(image.id));
              try {
                await ref
                    .read(patientsRepositoryProvider)
                    .deletePatientProntuarioProcedureImage(
                      patientId: patientId,
                      procedureId: item.id,
                      imageId: image.id,
                    );
                existingImages.removeWhere((saved) => saved.id == image.id);
                await _refreshAll(ref);
                if (!modalContext.mounted) return;
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  const SnackBar(content: Text('Imagem removida.')),
                );
              } catch (error) {
                if (!modalContext.mounted) return;
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  SnackBar(content: Text('Falha ao remover imagem: $error')),
                );
              } finally {
                if (modalContext.mounted) {
                  setModalState(() => deletingImageIds.remove(image.id));
                }
              }
            }

            Future<void> save() async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  const SnackBar(
                      content: Text('Informe o nome do procedimento.')),
                );
                return;
              }
              if (dateController.text.trim().isEmpty) {
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  const SnackBar(
                      content: Text('Informe a data do procedimento.')),
                );
                return;
              }

              final payload = <String, dynamic>{
                'nome_procedimento': nameController.text.trim(),
                'data_procedimento': dateController.text.trim(),
                'profissional_responsavel': professionalController.text.trim(),
                'descricao': descriptionController.text.trim(),
                'observacoes': notesController.text.trim(),
              };

              setModalState(() => saving = true);
              try {
                if (item == null) {
                  await ref
                      .read(patientsRepositoryProvider)
                      .createPatientProntuarioProcedure(
                        patientId: patientId,
                        payload: payload,
                        images: selectedFiles,
                      );
                } else {
                  await ref
                      .read(patientsRepositoryProvider)
                      .updatePatientProntuarioProcedure(
                        patientId: patientId,
                        procedureId: item.id,
                        payload: payload,
                        images: selectedFiles,
                      );
                }
                await _refreshAll(ref);
                if (!modalContext.mounted) return;
                Navigator.of(modalContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(item == null
                        ? 'Procedimento salvo com sucesso.'
                        : 'Procedimento atualizado com sucesso.'),
                  ),
                );
              } catch (error) {
                if (!modalContext.mounted) return;
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  SnackBar(
                      content: Text('Falha ao salvar procedimento: $error')),
                );
              } finally {
                if (modalContext.mounted) {
                  setModalState(() => saving = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(modalContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item == null
                            ? 'Adicionar procedimento'
                            : 'Editar procedimento',
                        style: Theme.of(modalContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                            labelText: 'Nome do procedimento'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Data do procedimento',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: pickDate,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: professionalController,
                        decoration: const InputDecoration(
                            labelText: 'Profissional responsável'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Descrição'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Observações'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: pickImages,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          selectedFiles.isEmpty
                              ? 'Selecionar imagens'
                              : '${selectedFiles.length} imagem(ns) selecionada(s)',
                        ),
                      ),
                      if (item != null && existingImages.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Imagens já salvas',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: GKColors.neutral,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: existingImages
                              .map(
                                (image) => GestureDetector(
                                  onTap: () => _openExternalUrl(image.imageUrl),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          image.imageUrl,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            width: 64,
                                            height: 64,
                                            color: const Color(0xFFE2E8F0),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.broken_image_outlined,
                                              color: GKColors.neutral,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: InkWell(
                                          onTap: () => deleteSavedImage(image),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFDC2626),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: deletingImageIds
                                                    .contains(image.id)
                                                ? const SizedBox(
                                                    width: 10,
                                                    height: 10,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 1.6,
                                                      valueColor:
                                                          AlwaysStoppedAnimation(
                                                        Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.close,
                                                    size: 12,
                                                    color: Colors.white,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GKButton(
                              label: 'Cancelar',
                              variant: GKButtonVariant.secondary,
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(modalContext).pop(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GKButton(
                              label: saving ? 'Salvando...' : 'Salvar',
                              onPressed: saving ? null : save,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProcedure(
    BuildContext context,
    WidgetRef ref,
    ProntuarioProcedureItem item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir procedimento'),
        content: Text('Deseja excluir "${item.nomeProcedimento}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref
          .read(patientsRepositoryProvider)
          .deletePatientProntuarioProcedure(
            patientId: patientId,
            procedureId: item.id,
          );
      await _refreshAll(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Procedimento excluído.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao excluir procedimento: $error')),
      );
    }
  }

  Future<void> _openDocumentForm(
    BuildContext context,
    WidgetRef ref, {
    ProntuarioDocumentItem? item,
  }) async {
    final titleController = TextEditingController(text: item?.titulo ?? '');
    final descriptionController =
        TextEditingController(text: item?.descricao ?? '');
    var type = item?.tipoArquivo == 'imagem' ? 'imagem' : 'pdf';
    File? selectedFile;
    String selectedFileName = '';
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> pickFile() async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: false,
                type: FileType.custom,
                allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
              );
              final path = result?.files.single.path;
              if (path == null || path.isEmpty) return;
              final extension =
                  result?.files.single.extension?.toLowerCase() ?? '';
              setModalState(() {
                selectedFile = File(path);
                selectedFileName = result?.files.single.name ?? '';
                if (extension == 'pdf') {
                  type = 'pdf';
                } else {
                  type = 'imagem';
                }
              });
            }

            Future<void> save() async {
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  const SnackBar(
                      content: Text('Informe o título do documento.')),
                );
                return;
              }
              if (item == null && selectedFile == null) {
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  const SnackBar(content: Text('Selecione um arquivo.')),
                );
                return;
              }

              final payload = <String, dynamic>{
                'titulo': titleController.text.trim(),
                'descricao': descriptionController.text.trim(),
                'tipo_arquivo': type,
              };

              setModalState(() => saving = true);
              try {
                if (item == null) {
                  await ref
                      .read(patientsRepositoryProvider)
                      .createPatientProntuarioDocument(
                        patientId: patientId,
                        payload: payload,
                        file: selectedFile,
                      );
                } else {
                  await ref
                      .read(patientsRepositoryProvider)
                      .updatePatientProntuarioDocument(
                        patientId: patientId,
                        documentId: item.id,
                        payload: payload,
                        file: selectedFile,
                      );
                }
                await _refreshAll(ref);
                if (!modalContext.mounted) return;
                Navigator.of(modalContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(item == null
                        ? 'Documento salvo com sucesso.'
                        : 'Documento atualizado com sucesso.'),
                  ),
                );
              } catch (error) {
                if (!modalContext.mounted) return;
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  SnackBar(content: Text('Falha ao salvar documento: $error')),
                );
              } finally {
                if (modalContext.mounted) {
                  setModalState(() => saving = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(modalContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item == null
                            ? 'Adicionar documento'
                            : 'Editar documento',
                        style: Theme.of(modalContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Título'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Descrição'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        items: const [
                          DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                          DropdownMenuItem(
                              value: 'imagem', child: Text('Imagem')),
                        ],
                        onChanged: (value) => setModalState(() {
                          type = value ?? 'pdf';
                        }),
                        decoration:
                            const InputDecoration(labelText: 'Tipo de arquivo'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          selectedFileName.isEmpty
                              ? 'Selecionar arquivo (PDF/Imagem)'
                              : selectedFileName,
                        ),
                      ),
                      if (item != null && item.arquivoUrl.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _openExternalUrl(item.arquivoUrl),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Abrir arquivo atual'),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GKButton(
                              label: 'Cancelar',
                              variant: GKButtonVariant.secondary,
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(modalContext).pop(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GKButton(
                              label: saving ? 'Salvando...' : 'Salvar',
                              onPressed: saving ? null : save,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteDocument(
    BuildContext context,
    WidgetRef ref,
    ProntuarioDocumentItem item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir documento'),
        content: Text('Deseja excluir "${item.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref
          .read(patientsRepositoryProvider)
          .deletePatientProntuarioDocument(
            patientId: patientId,
            documentId: item.id,
          );
      await _refreshAll(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento excluído.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao excluir documento: $error')),
      );
    }
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    if (rawUrl.trim().isEmpty) return;
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _toDateInput(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _MedicationsCard extends StatelessWidget {
  const _MedicationsCard({
    required this.state,
    required this.onAdd,
    required this.onEdit,
    required this.onDeactivate,
  });

  final AsyncValue<List<ProntuarioMedicationItem>> state;
  final VoidCallback onAdd;
  final ValueChanged<ProntuarioMedicationItem> onEdit;
  final ValueChanged<ProntuarioMedicationItem> onDeactivate;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Medicações em uso',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          state.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Erro ao carregar medicações: $error'),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nenhuma medicação cadastrada.'),
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.nomeMedicamento,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                GKBadge(
                                  label: item.emUso ? 'Em uso' : 'Inativo',
                                  background: item.emUso
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFE5E7EB),
                                  foreground: item.emUso
                                      ? const Color(0xFF166534)
                                      : const Color(0xFF475569),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item.dosagem.isEmpty ? '-' : item.dosagem} • ${item.frequencia.isEmpty ? '-' : item.frequencia}',
                              style: const TextStyle(color: GKColors.neutral),
                            ),
                            if (item.descricao.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(item.descricao),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => onEdit(item),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Editar'),
                                ),
                                if (item.emUso)
                                  TextButton.icon(
                                    onPressed: () => onDeactivate(item),
                                    icon: const Icon(Icons.block_outlined),
                                    label: const Text('Desativar'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProceduresCard extends StatelessWidget {
  const _ProceduresCard({
    required this.state,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenImage,
  });

  final AsyncValue<List<ProntuarioProcedureItem>> state;
  final VoidCallback onAdd;
  final ValueChanged<ProntuarioProcedureItem> onEdit;
  final ValueChanged<ProntuarioProcedureItem> onDelete;
  final ValueChanged<String> onOpenImage;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Histórico de procedimentos',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          state.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Erro ao carregar procedimentos: $error'),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nenhum procedimento cadastrado.'),
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.nomeProcedimento,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.dataProcedimento == null
                                  ? '-'
                                  : formatDate(item.dataProcedimento!),
                              style: const TextStyle(color: GKColors.neutral),
                            ),
                            if (item.profissionalResponsavel.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                  'Profissional: ${item.profissionalResponsavel}'),
                            ],
                            if (item.descricao.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(item.descricao),
                            ],
                            if (item.images.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: item.images
                                    .map(
                                      (image) => GestureDetector(
                                        onTap: () =>
                                            onOpenImage(image.imageUrl),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            image.imageUrl,
                                            width: 64,
                                            height: 64,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 64,
                                              height: 64,
                                              color: const Color(0xFFE2E8F0),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.broken_image_outlined,
                                                color: GKColors.neutral,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => onEdit(item),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Editar'),
                                ),
                                TextButton.icon(
                                  onPressed: () => onDelete(item),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Excluir'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({
    required this.state,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenDocument,
  });

  final AsyncValue<List<ProntuarioDocumentItem>> state;
  final VoidCallback onAdd;
  final ValueChanged<ProntuarioDocumentItem> onEdit;
  final ValueChanged<ProntuarioDocumentItem> onDelete;
  final ValueChanged<String> onOpenDocument;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Documentos digitais',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          state.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Erro ao carregar documentos: $error'),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nenhum documento cadastrado.'),
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
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
                                    item.titulo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.tipoArquivo.toUpperCase()} • ${item.criadoEm == null ? '-' : formatDate(item.criadoEm!)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: GKColors.neutral,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'open') {
                                  onOpenDocument(item.arquivoUrl);
                                  return;
                                }
                                if (value == 'edit') {
                                  onEdit(item);
                                  return;
                                }
                                if (value == 'delete') {
                                  onDelete(item);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'open',
                                  child: Text('Abrir'),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Excluir'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
