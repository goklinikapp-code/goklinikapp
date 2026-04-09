import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../../../core/widgets/notification_bell_action.dart';
import '../domain/chat_models.dart';
import 'chat_controller.dart';

enum InboxFilterChip {
  all,
  unread,
  answered,
  closed,
}

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  Timer? _pollTimer;
  InboxFilterChip _filter = InboxFilterChip.all;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      ref.read(chatInboxProvider.notifier).load(forceLoading: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _openReplySheet(DoctorInboxMessage item) async {
    final language = ref.read(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DoctorReplySheet(
          message: item,
          t: t,
          onSubmit: (answer) async {
            await ref.read(chatInboxProvider.notifier).reply(
                  requestId: item.id,
                  answer: answer,
                );
          },
        );
      },
    );

    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('chat_doctor_sent_success'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);
    final inboxState = ref.watch(chatInboxProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('chat_inbox_title')),
        actions: [
          const NotificationBellAction(),
          IconButton(
            onPressed: () =>
                ref.read(chatInboxProvider.notifier).load(forceLoading: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: inboxState.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 7,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => const GKLoadingShimmer(height: 120),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${t('chat_inbox_load_error_prefix')}: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                t('chat_inbox_empty'),
              ),
            );
          }

          final filtered =
              items.where((item) => _matchesFilter(item, _filter)).toList();

          return Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _chip(t('appointments_filter_all'), InboxFilterChip.all),
                    _chip(t('chat_filter_unread'), InboxFilterChip.unread),
                    _chip(t('chat_filter_answered'), InboxFilterChip.answered),
                    _chip(t('chat_filter_closed'), InboxFilterChip.closed),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          t('chat_inbox_empty_filtered'),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final status =
                              _statusVisual(colorScheme, item.status, t);

                          return GKCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GKAvatar(
                                      name: item.patientName,
                                      imageUrl: item.patientAvatarUrl,
                                      radius: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.patientName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.patientEmail,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        GKBadge(
                                          label: status.label,
                                          background: status.background,
                                          foreground: status.foreground,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          DateFormat('dd/MM HH:mm').format(
                                            item.createdAt.toLocal(),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  item.question,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _emojiTextStyle(
                                    context,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.answer.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t('chat_answered'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.answer,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: _emojiTextStyle(
                                            context,
                                            color: const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: SizedBox(
                                    width: 170,
                                    child: GKButton(
                                      label: item.isAnswered
                                          ? t('chat_view_details')
                                          : t('chat_reply'),
                                      variant: item.isAnswered
                                          ? GKButtonVariant.secondary
                                          : GKButtonVariant.primary,
                                      onPressed: () => _openReplySheet(item),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesFilter(DoctorInboxMessage item, InboxFilterChip filter) {
    switch (filter) {
      case InboxFilterChip.all:
        return true;
      case InboxFilterChip.unread:
        return item.status == 'open';
      case InboxFilterChip.answered:
        return item.status == 'answered';
      case InboxFilterChip.closed:
        return item.status == 'closed';
    }
  }

  Widget _chip(String label, InboxFilterChip value) {
    final active = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: GKColors.primary,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: active ? Colors.white : GKColors.darkBackground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DoctorReplySheet extends StatefulWidget {
  const _DoctorReplySheet({
    required this.message,
    required this.t,
    required this.onSubmit,
  });

  final DoctorInboxMessage message;
  final String Function(String key) t;
  final Future<void> Function(String answer) onSubmit;

  @override
  State<_DoctorReplySheet> createState() => _DoctorReplySheetState();
}

class _DoctorReplySheetState extends State<_DoctorReplySheet> {
  late final TextEditingController _controller;
  late bool _editing;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.answer);
    _editing = !widget.message.isAnswered;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final answer = _controller.text.trim();
    if (answer.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.t('chat_reply_min_chars')),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.onSubmit(answer);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.t('chat_send_error')),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message.patientName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.message.patientEmail,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surfaceContainerLow,
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                widget.message.question,
                style: _emojiTextStyle(context),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.message.isAnswered && !_editing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.t('chat_current_answer'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message.answer.trim().isEmpty
                          ? widget.t('chat_no_answer')
                          : widget.message.answer,
                      style: _emojiTextStyle(context),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                widget.t('chat_reply'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                maxLines: 5,
                minLines: 4,
                decoration: InputDecoration(
                  hintText: widget.t('chat_reply_hint'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GKButton(
                    label: (widget.message.isAnswered && !_editing)
                        ? widget.t('chat_close')
                        : widget.t('cancel'),
                    variant: GKButtonVariant.secondary,
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GKButton(
                    label: widget.message.isAnswered && !_editing
                        ? widget.t('chat_edit_answer')
                        : (_sending
                            ? widget.t('chat_sending')
                            : widget.t('save')),
                    onPressed: _sending
                        ? null
                        : () {
                            if (widget.message.isAnswered && !_editing) {
                              setState(() => _editing = true);
                              return;
                            }
                            _submit();
                          },
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

_StatusVisual _statusVisual(
  ColorScheme colorScheme,
  String status,
  String Function(String key) t,
) {
  switch (status) {
    case 'answered':
      return _StatusVisual(
        label: t('chat_filter_answered'),
        background: colorScheme.secondary.withValues(alpha: 0.2),
        foreground: colorScheme.secondary,
      );
    case 'closed':
      return _StatusVisual(
        label: t('chat_filter_closed'),
        background: colorScheme.outline.withValues(alpha: 0.2),
        foreground: colorScheme.onSurfaceVariant,
      );
    case 'open':
    default:
      return _StatusVisual(
        label: t('appointments_status_pending'),
        background: colorScheme.tertiary.withValues(alpha: 0.2),
        foreground: colorScheme.tertiary,
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
