import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../domain/postop_models.dart';
import 'postop_controller.dart';

class _UrgentTicketDraft {
  const _UrgentTicketDraft({
    required this.message,
    this.imagePath,
  });

  final String message;
  final String? imagePath;
}

class _UrgentTicketComposerSheet extends StatefulWidget {
  const _UrgentTicketComposerSheet({
    required this.currentDay,
    required this.totalDays,
  });

  final int currentDay;
  final int totalDays;

  @override
  State<_UrgentTicketComposerSheet> createState() =>
      _UrgentTicketComposerSheetState();
}

class _UrgentTicketComposerSheetState
    extends State<_UrgentTicketComposerSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _selectedImagePath;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (!mounted || file == null) {
      return;
    }
    setState(() => _selectedImagePath = file.path);
  }

  void _submit() {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Descreva a dúvida urgente para enviar.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _UrgentTicketDraft(
        message: message,
        imagePath: _selectedImagePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dúvida urgente',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jornada: Dia ${widget.currentDay} de ${widget.totalDays}',
            style: const TextStyle(color: GKColors.neutral),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mensagem',
              hintText: 'Descreva com detalhes o que você está sentindo.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Anexar imagem (opcional)'),
          ),
          if ((_selectedImagePath ?? '').isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Imagem selecionada.',
                style: TextStyle(
                  color: GKColors.neutral,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GKButton(
                  label: 'Enviar',
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PostOpScreen extends ConsumerStatefulWidget {
  const PostOpScreen({super.key});

  @override
  ConsumerState<PostOpScreen> createState() => _PostOpScreenState();
}

class _PostOpScreenState extends ConsumerState<PostOpScreen> {
  final TextEditingController _notesController = TextEditingController();
  final Set<String> _updatingChecklist = <String>{};

  double _painLevel = 0;
  bool _hasFever = false;
  bool _sendingCheckin = false;
  bool _uploadingPhoto = false;
  bool _showRiskAlert = false;
  String? _syncedSnapshot;
  DateTime? _lastUrgentTicketSentAt;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _syncInputsWithJourney(PostOpJourney journey) {
    final todayCheckinId = journey.todayCheckin?.id ?? 'none';
    final snapshot =
        '${journey.id}:${journey.currentDay}:${journey.checkinSubmittedToday}:$todayCheckinId';

    if (_syncedSnapshot == snapshot) {
      return;
    }

    _syncedSnapshot = snapshot;
    final checkin = journey.todayCheckin;
    _painLevel = (checkin?.painLevel ?? 0).toDouble();
    _hasFever = checkin?.hasFever ?? false;
    _notesController.text = checkin?.notes ?? '';
    _showRiskAlert = false;
  }

  List<PostOpChecklistItem> _resolveTodayChecklist(PostOpJourney journey) {
    if (journey.todayChecklist.isNotEmpty) {
      return journey.todayChecklist;
    }

    final currentProtocol = journey.protocol.where((item) {
      return item.dayNumber == journey.currentDay || item.isToday;
    }).toList();

    return currentProtocol
        .expand((item) => item.checklistItems)
        .toList(growable: false);
  }

  Future<void> _submitCheckin(PostOpJourney journey) async {
    if (_sendingCheckin || journey.checkinSubmittedToday) {
      return;
    }

    final painLevel = _painLevel.round();
    final hasFever = _hasFever;

    setState(() => _sendingCheckin = true);
    try {
      await ref.read(postOpControllerProvider.notifier).submitCheckin(
            painLevel: painLevel,
            hasFever: hasFever,
            notes: _notesController.text.trim(),
            journeyId: journey.id,
          );
      if (!mounted) {
        return;
      }

      final showRisk = painLevel >= 8 || hasFever;
      setState(() => _showRiskAlert = showRisk);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in enviado com sucesso.')),
      );
      if (showRisk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF8A4B00),
            content: Text(
              '⚠️ Sua resposta indica possível atenção clínica. A clínica foi notificada.',
            ),
          ),
        );
      }
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final detail = (error.response?.data is Map<String, dynamic>)
          ? (error.response?.data['detail'] ?? '').toString()
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail.isNotEmpty
                ? detail
                : 'Não foi possível enviar o check-in agora.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível enviar o check-in agora.')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingCheckin = false);
      }
    }
  }

  Future<void> _toggleChecklist({
    required String checklistId,
    required bool completed,
  }) async {
    if (_updatingChecklist.contains(checklistId)) {
      return;
    }

    setState(() => _updatingChecklist.add(checklistId));
    try {
      await ref.read(postOpControllerProvider.notifier).updateChecklist(
            checklistId: checklistId,
            completed: completed,
          );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao atualizar checklist.')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingChecklist.remove(checklistId));
      }
    }
  }

  Future<void> _pickAndUploadPhoto(PostOpJourney journey) async {
    if (_uploadingPhoto) {
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null) {
      return;
    }

    setState(() => _uploadingPhoto = true);
    try {
      await ref.read(postOpControllerProvider.notifier).uploadPhoto(
            journeyId: journey.id,
            dayNumber: journey.currentDay,
            path: file.path,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto enviada com sucesso.')),
      );
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final detail = _extractErrorDetail(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail.isNotEmpty ? detail : 'Não foi possível enviar a foto.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível enviar a foto.')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  String _extractErrorDetail(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = (data['detail'] ?? '').toString().trim();
      if (detail.isNotEmpty) {
        return detail;
      }
      final imageErrors = data['image'];
      if (imageErrors is List && imageErrors.isNotEmpty) {
        final first = imageErrors.first.toString().trim();
        if (first.isNotEmpty) {
          return first;
        }
      }
      final nonFieldErrors = data['non_field_errors'];
      if (nonFieldErrors is List && nonFieldErrors.isNotEmpty) {
        final first = nonFieldErrors.first.toString().trim();
        if (first.isNotEmpty) {
          return first;
        }
      }
    }
    return '';
  }

  void _showPostOpSnack(String message, {Color? backgroundColor}) {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
          ),
        );
    });
  }

  Future<void> _openUrgentTicketModal(PostOpJourney journey) async {
    final draft = await showModalBottomSheet<_UrgentTicketDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UrgentTicketComposerSheet(
        currentDay: journey.currentDay,
        totalDays: journey.totalDays,
      ),
    );

    if (!mounted || draft == null) {
      return;
    }

    final now = DateTime.now();
    if (_lastUrgentTicketSentAt != null &&
        now.difference(_lastUrgentTicketSentAt!) < const Duration(minutes: 2)) {
      _showPostOpSnack(
        'Você enviou uma dúvida há pouco. Aguarde um instante para enviar outra.',
      );
      return;
    }

    try {
      await ref.read(postOpControllerProvider.notifier).createUrgentTicket(
            message: draft.message,
            imagePath: draft.imagePath,
          );
      if (!mounted) {
        return;
      }
      _lastUrgentTicketSentAt = DateTime.now();
      _showPostOpSnack('Dúvida urgente enviada para a clínica.');
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final detail = _extractErrorDetail(error);
      _showPostOpSnack(
        detail.isNotEmpty
            ? detail
            : 'Não foi possível enviar a dúvida urgente agora.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showPostOpSnack('Não foi possível enviar a dúvida urgente agora.');
    }
  }

  void _openPhotoPreview(EvolutionPhotoItem photo) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(),
          body: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: photo.photoUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _mapStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Concluída';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Em andamento';
    }
  }

  Color _mapStatusBackground(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFFD8F2E0);
      case 'cancelled':
        return const Color(0xFFF9D8D8);
      default:
        return const Color(0xFFE7ECFA);
    }
  }

  Color _mapStatusForeground(String status) {
    switch (status) {
      case 'completed':
        return GKColors.secondary;
      case 'cancelled':
        return GKColors.danger;
      default:
        return GKColors.primary;
    }
  }

  String _mapHistoryStatus(String status) {
    switch (status) {
      case 'ok':
        return 'OK';
      case 'enviado':
        return 'Enviado';
      case 'pendente':
        return 'Pendente';
      case 'hoje':
        return 'Hoje';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postOpControllerProvider);
    final activeJourney = state.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sua Recuperação'),
        actions: [
          IconButton(
            onPressed: () => ref.read(postOpControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final journey = activeJourney;
          if (journey == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Disponível quando houver uma jornada pós-operatória ativa.',
                ),
              ),
            );
            return;
          }
          _openUrgentTicketModal(journey);
        },
        backgroundColor: GKColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.emergency),
        label: const Text('Dúvida urgente'),
      ),
      body: state.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => const GKLoadingShimmer(height: 120),
        ),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar pós-op: $error')),
        data: (journey) {
          if (journey == null) {
            return const Center(
              child:
                  Text('Você ainda não possui jornada pós-operatória ativa.'),
            );
          }

          _syncInputsWithJourney(journey);
          final todayChecklist = _resolveTodayChecklist(journey);

          return RefreshIndicator(
            onRefresh: () => ref.read(postOpControllerProvider.notifier).load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                GKCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sua recuperação',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dia ${journey.currentDay} de ${journey.totalDays}',
                        style: const TextStyle(
                          color: GKColors.neutral,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GKBadge(
                        label: _mapStatusLabel(journey.status),
                        background: _mapStatusBackground(journey.status),
                        foreground: _mapStatusForeground(journey.status),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GKCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Como você está hoje?',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Dor'),
                          const Spacer(),
                          Text(
                            _painLevel.round().toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: GKColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _painLevel,
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: _painLevel.round().toString(),
                        onChanged: journey.checkinSubmittedToday
                            ? null
                            : (value) => setState(() => _painLevel = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Teve febre hoje?'),
                        value: _hasFever,
                        onChanged: journey.checkinSubmittedToday
                            ? null
                            : (value) => setState(() => _hasFever = value),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 4,
                        enabled: !journey.checkinSubmittedToday,
                        cursorColor: GKColors.primary,
                        style: const TextStyle(color: GKColors.darkBackground),
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (journey.checkinSubmittedToday)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9F7ED),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Check-in de hoje já enviado. Volte amanhã para um novo registro.',
                            style: TextStyle(color: GKColors.secondary),
                          ),
                        ),
                      if (_showRiskAlert)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '⚠️ Sua resposta indica possível atenção clínica. A clínica foi notificada.',
                            style: TextStyle(color: Color(0xFF9A3412)),
                          ),
                        ),
                      GKButton(
                        label: journey.checkinSubmittedToday
                            ? 'Check-in enviado hoje'
                            : 'Enviar check-in',
                        onPressed: journey.checkinSubmittedToday
                            ? null
                            : () => _submitCheckin(journey),
                        isLoading: _sendingCheckin,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GKCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checklist de cuidados',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (todayChecklist.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Nenhuma tarefa para o dia de hoje.'),
                        )
                      else
                        ...todayChecklist.map((item) {
                          final isUpdating =
                              _updatingChecklist.contains(item.id);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: item.isCompleted,
                            title: Text(item.itemText),
                            secondary: isUpdating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : null,
                            onChanged: isUpdating
                                ? null
                                : (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    _toggleChecklist(
                                      checklistId: item.id,
                                      completed: value,
                                    );
                                  },
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GKCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fotos da recuperação',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _uploadingPhoto
                            ? null
                            : () => _pickAndUploadPhoto(journey),
                        icon: _uploadingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Enviar foto'),
                      ),
                      const SizedBox(height: 8),
                      if (journey.photos.isEmpty)
                        const Text('Nenhuma foto enviada ainda.')
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: journey.photos.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemBuilder: (context, index) {
                            final photo = journey.photos[index];
                            return InkWell(
                              onTap: () => _openPhotoPreview(photo),
                              borderRadius: BorderRadius.circular(12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: photo.photoUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GKCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Histórico',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (journey.history.isEmpty)
                        const Text('Sem histórico por enquanto.')
                      else
                        ...journey.history.map((item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFE7ECFA),
                                child: Text(
                                  '${item.day}',
                                  style: const TextStyle(
                                    color: GKColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(item.title),
                              subtitle: Text(_mapHistoryStatus(item.status)),
                              trailing: item.hasCheckin
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: GKColors.secondary,
                                    )
                                  : null,
                            )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Início: ${formatDate(journey.startDate ?? journey.surgeryDate)}',
                  style: const TextStyle(color: GKColors.neutral),
                ),
                if (journey.endDate != null)
                  Text(
                    'Previsão de término: ${formatDate(journey.endDate!)}',
                    style: const TextStyle(color: GKColors.neutral),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
