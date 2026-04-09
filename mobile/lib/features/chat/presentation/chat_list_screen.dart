import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
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

  String _t(String key) {
    final language = ref.read(appPreferencesControllerProvider).language;
    return appTr(key: key, language: language);
  }

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
        final language = ref.read(appPreferencesControllerProvider).language;
        return _UrgentQuestionSheet(
          language: language,
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
      SnackBar(content: Text(_t('chat_doctor_sent_success'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final urgentState = ref.watch(urgentMedicalRequestsProvider);
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('chat_list_title')),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GKBadge(
                  label: t('chat_premium_badge'),
                  background: Colors.white24,
                  foreground: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  t('chat_premium_headline'),
                  style: const TextStyle(
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
                  t('chat_team_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('chat_team_description'),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                GKButton(
                  label: t('chat_team_button'),
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
                  t('chat_doctor_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('chat_doctor_description'),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                GKButton(
                  label: t('chat_doctor_button'),
                  variant: GKButtonVariant.secondary,
                  icon: const Icon(Icons.medical_information_outlined),
                  onPressed: _openUrgentQuestionForm,
                ),
                const SizedBox(height: 14),
                urgentState.when(
                  loading: () => Text(t('chat_urgent_loading')),
                  error: (_, __) => Text(t('chat_urgent_load_error')),
                  data: (items) {
                    if (items.isEmpty) {
                      return Text(t('chat_urgent_empty'));
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
                                      style: _emojiTextStyle(
                                        context,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GKBadge(
                                    label: answered
                                        ? t('chat_answered')
                                        : t('chat_waiting'),
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
                                  style: _emojiTextStyle(
                                    context,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
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

TextStyle _emojiTextStyle(
  BuildContext context, {
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  final fallback = <String>[
    ...?base.fontFamilyFallback,
    'AppleColorEmoji',
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
  ];

  return base.copyWith(
    fontSize: fontSize ?? base.fontSize,
    fontWeight: fontWeight ?? base.fontWeight,
    color: color ?? base.color,
    fontFamilyFallback: fallback.toSet().toList(),
  );
}

class _UrgentQuestionSheet extends StatefulWidget {
  const _UrgentQuestionSheet({
    required this.onSubmit,
    required this.language,
  });

  final Future<void> Function(String question) onSubmit;
  final String language;

  @override
  State<_UrgentQuestionSheet> createState() => _UrgentQuestionSheetState();
}

class _UrgentQuestionSheetState extends State<_UrgentQuestionSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  String t(String key) => appTr(key: key, language: widget.language);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _controller.text.trim();
    if (question.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('chat_urgent_min_chars'))),
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
        SnackBar(content: Text(t('chat_send_error'))),
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
              t('chat_urgent_sheet_title'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              t('chat_urgent_sheet_description'),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 4,
              decoration: InputDecoration(
                hintText: t('chat_urgent_sheet_hint'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GKButton(
                    label: t('cancel'),
                    variant: GKButtonVariant.secondary,
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GKButton(
                    label: _sending ? t('chat_sending') : t('send'),
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
