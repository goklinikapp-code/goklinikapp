import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../post_op/presentation/postop_controller.dart';
import 'chat_controller.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(urgentMedicalRequestsProvider.notifier).load();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      ref.read(urgentMedicalRequestsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _openUrgentQuestionForm() async {
    final wasSent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _UrgentQuestionSheet(
          onSubmit: (question) async {
            await ref
                .read(urgentMedicalRequestsProvider.notifier)
                .send(question);
          },
        );
      },
    );
    if (!mounted || wasSent != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Mensagem enviada com sucesso. A equipe médica responderá em breve.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final urgentState = ref.watch(urgentMedicalRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat com a Clínica'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(chatMessagesProvider(aiChatRoomId));
              ref.read(urgentMedicalRequestsProvider.notifier).load();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GKCard(
            color: colorScheme.primary,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GKBadge(
                  label: 'ATENDIMENTO PREMIUM',
                  background: Colors.white24,
                  foreground: Colors.white,
                ),
                SizedBox(height: 10),
                Text(
                  'Cuidado sob medida para sua recuperação',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GKCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conversar com a equipe da clínica',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tire dúvidas sobre seu atendimento, consultas, pós-operatório e orientações gerais.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                GKButton(
                  label: 'Conversar com a equipe',
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => context.push('/chat/room/$aiChatRoomId'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GKCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mensagem para o médico',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Você envia sua dúvida e o médico responderá assim que possível.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                GKButton(
                  label: 'Enviar mensagem ao médico',
                  variant: GKButtonVariant.secondary,
                  icon: const Icon(Icons.medical_information_outlined),
                  onPressed: _openUrgentQuestionForm,
                ),
                const SizedBox(height: 14),
                urgentState.when(
                  loading: () =>
                      const Text('Carregando suas mensagens enviadas...'),
                  error: (_, __) => const Text(
                    'Não foi possível carregar seu histórico de mensagens agora.',
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Text(
                        'Você ainda não enviou nenhuma mensagem para o médico.',
                      );
                    }
                    final latest = items.take(3).toList();
                    return Column(
                      children: latest.map((item) {
                        final answered = item.isAnswered;
                        final chipBg = answered
                            ? colorScheme.secondary.withValues(alpha: 0.14)
                            : colorScheme.tertiary.withValues(alpha: 0.2);
                        final chipFg = answered
                            ? colorScheme.secondary
                            : colorScheme.tertiary;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: colorScheme.surfaceContainerLow,
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.question,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GKBadge(
                                    label:
                                        answered ? 'Respondida' : 'Aguardando',
                                    background: chipBg,
                                    foreground: chipFg,
                                  ),
                                ],
                              ),
                              if (answered &&
                                  item.answer.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  item.answer,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentQuestionSheet extends StatefulWidget {
  const _UrgentQuestionSheet({
    required this.onSubmit,
  });

  final Future<void> Function(String question) onSubmit;

  @override
  State<_UrgentQuestionSheet> createState() => _UrgentQuestionSheetState();
}

class _UrgentQuestionSheetState extends State<_UrgentQuestionSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _controller.text.trim();
    if (question.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite pelo menos 5 caracteres na sua dúvida.'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.onSubmit(question);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível enviar agora. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enviar mensagem para o médico',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sua mensagem será enviada para a equipe médica e respondida de forma assíncrona.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: 'Descreva sua dúvida com detalhes...',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GKButton(
                    label: 'Cancelar',
                    variant: GKButtonVariant.secondary,
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GKButton(
                    label: _sending ? 'Enviando...' : 'Enviar',
                    onPressed: _sending ? null : _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
