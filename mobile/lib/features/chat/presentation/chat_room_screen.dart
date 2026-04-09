import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/utils/api_media_url.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../branding/presentation/tenant_branding_controller.dart';
import 'chat_controller.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageController = TextEditingController();
  bool _sending = false;
  bool _awaitingAiReplyVisual = false;
  bool _staffTyping = false;
  Timer? _typingPollTimer;
  Timer? _messagesPollTimer;
  final Set<String> _delayedAssistantMessageIds = <String>{};
  bool get _isAiChat => widget.roomId == aiChatRoomId;

  String _t(String key) {
    final language = ref.read(appPreferencesControllerProvider).language;
    return appTr(key: key, language: language);
  }

  List<String> get _quickReplies => [
        _t('chat_quick_reply_ok'),
        _t('chat_quick_reply_pain'),
        _t('chat_quick_reply_medication'),
        _t('chat_quick_reply_drive'),
      ];

  @override
  void initState() {
    super.initState();
    if (_isAiChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshAiMessagesSilently());
        unawaited(_refreshStaffTypingStatus());
      });
      _typingPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_refreshStaffTypingStatus());
      });
      _messagesPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_refreshAiMessagesSilently());
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatMessagesProvider(widget.roomId).notifier).markRead();
      });
    }
  }

  @override
  void dispose() {
    _typingPollTimer?.cancel();
    _messagesPollTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _refreshAiMessagesSilently() async {
    if (!_isAiChat || !mounted) return;
    await ref
        .read(chatMessagesProvider(widget.roomId).notifier)
        .refreshLatest();
  }

  Future<void> _refreshStaffTypingStatus() async {
    if (!_isAiChat || !mounted) return;
    final isTyping = await ref
        .read(chatMessagesProvider(widget.roomId).notifier)
        .fetchAiTypingStatus();
    if (!mounted) return;
    setState(() {
      _staffTyping = isTyping;
    });
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final notifier = ref.read(chatMessagesProvider(widget.roomId).notifier);
    final previousItems =
        ref.read(chatMessagesProvider(widget.roomId)).valueOrNull ?? const [];
    final previousIds = previousItems.map((item) => item.id).toSet();
    setState(() {
      _sending = true;
    });

    try {
      await notifier.send(content: text);
      _messageController.clear();
      ref.read(chatRoomsProvider.notifier).load();

      if (_isAiChat) {
        final updatedItems =
            ref.read(chatMessagesProvider(widget.roomId)).valueOrNull ??
                const [];
        String? delayedAssistantId;
        for (final item in updatedItems) {
          final isNewMessage = !previousIds.contains(item.id);
          if (!isNewMessage) continue;
          if (item.senderId == 'assistant') {
            delayedAssistantId = item.id;
            break;
          }
        }

        final assistantId = delayedAssistantId;
        if (assistantId != null && mounted) {
          setState(() {
            _delayedAssistantMessageIds.add(assistantId);
          });
          // Show user message first, then typing bubble, then assistant answer.
          await Future.delayed(const Duration(milliseconds: 220));
          if (!mounted) return;
          setState(() {
            _awaitingAiReplyVisual = true;
          });
          await Future.delayed(const Duration(seconds: 3));
          if (!mounted) return;
          setState(() {
            _delayedAssistantMessageIds.remove(assistantId);
            _awaitingAiReplyVisual = false;
          });
        }
      }
    } catch (error) {
      if (!mounted) return;
      if (_isAiChat) {
        setState(() {
          _awaitingAiReplyVisual = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
      if (_isAiChat) {
        unawaited(_refreshStaffTypingStatus());
      }
    }
  }

  Future<void> _sendImage() async {
    if (_isAiChat) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('chat_room_text_only'))),
      );
      return;
    }

    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    final encoded = base64Encode(bytes);
    final payload = 'data:image/jpeg;base64,$encoded';

    setState(() => _sending = true);
    try {
      await ref.read(chatMessagesProvider(widget.roomId).notifier).send(
            content: payload,
            messageType: 'image',
          );
      ref.read(chatRoomsProvider.notifier).load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final payload = error.response?.data;
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
      }
    }
    return _t('chat_room_send_error');
  }

  String _displayContent(String value) {
    var sanitized = value
        .replaceAll(
          RegExp(r'assistente\s+IA', caseSensitive: false),
          _t('chat_care_label'),
        )
        .replaceAll(
          RegExp(r'\bIA\b', caseSensitive: false),
          _t('chat_care_short_label'),
        )
        .replaceAll(
          'opção de dúvida urgente',
          _t('chat_doctor_option_label'),
        );

    return sanitized;
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(chatMessagesProvider(widget.roomId));
    final session = ref.watch(authControllerProvider).session;
    final tenantBranding = ref.watch(tenantBrandingProvider);
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);
    final colorScheme = Theme.of(context).colorScheme;
    final clinicName = tenantBranding.name.trim().isNotEmpty
        ? tenantBranding.name.trim()
        : t('chat_room_team_label');
    final aiLogoUrl = (tenantBranding.logoUrl ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GKAvatar(
              name: _isAiChat ? clinicName : t('chat_room_team_short'),
              imageUrl: _isAiChat && aiLogoUrl.isNotEmpty ? aiLogoUrl : null,
              radius: 18,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAiChat ? clinicName : t('chat_room_team_label'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  _isAiChat
                      ? t('chat_room_digital_care')
                      : t('chat_room_online'),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('${t('chat_room_error_prefix')} $error')),
              data: (items) {
                final visibleItems = items
                    .where((item) =>
                        !_delayedAssistantMessageIds.contains(item.id))
                    .toList(growable: false);
                final showTypingIndicator =
                    _isAiChat && (_awaitingAiReplyVisual || _staffTyping);

                if (visibleItems.isEmpty && !showTypingIndicator) {
                  return Center(child: Text(t('chat_room_empty')));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount:
                      visibleItems.length + (showTypingIndicator ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (showTypingIndicator && index == 0) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: _TypingBubble(),
                        ),
                      );
                    }

                    final messageIndex = index - (showTypingIndicator ? 1 : 0);
                    final message = visibleItems[messageIndex];
                    final mine = session?.user.id == message.senderId ||
                        message.senderId == 'user';

                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              mine ? colorScheme.primary : colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 6,
                                offset: Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.isImage)
                              _MessageImage(content: message.content)
                            else
                              Text(
                                _displayContent(message.content),
                                style: _emojiTextStyle(
                                  context,
                                  color: mine
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurface,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('HH:mm')
                                      .format(message.createdAt.toLocal()),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: mine
                                        ? colorScheme.onPrimary
                                            .withValues(alpha: 0.72)
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (mine)
                                  Icon(
                                    message.isRead
                                        ? Icons.done_all
                                        : Icons.done,
                                    size: 12,
                                    color: message.isRead
                                        ? Colors.greenAccent
                                        : Colors.white70,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _isAiChat ? 0 : _quickReplies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final text = _quickReplies[index];
                return ActionChip(
                  label: Text(text),
                  onPressed: () {
                    _messageController.text = text;
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  if (!_isAiChat)
                    IconButton(
                      onPressed: _sending ? null : _sendImage,
                      icon: const Icon(Icons.add_circle_outline),
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      cursorColor: colorScheme.primary,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: t('chat_room_placeholder'),
                        hintStyle:
                            TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _sendText,
                    style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary),
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
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

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _opacityFor(int index) {
    final phase = (_controller.value + (index * 0.2)) % 1;
    final distance = (phase - 0.5).abs();
    final wave = (1 - (distance * 2)).clamp(0.0, 1.0).toDouble();
    return 0.35 + (wave * 0.65);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return Opacity(
                opacity: _opacityFor(index),
                child: Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trimmedContent = content.trim();
    final looksLikeRemoteImage = trimmedContent.startsWith('http://') ||
        trimmedContent.startsWith('https://') ||
        trimmedContent.startsWith('/');

    if (looksLikeRemoteImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          resolveApiMediaUrl(trimmedContent),
          width: 210,
          height: 160,
          fit: BoxFit.cover,
        ),
      );
    }

    if (trimmedContent.startsWith('data:image')) {
      final commaIndex = trimmedContent.indexOf(',');
      if (commaIndex > 0) {
        final encoded = trimmedContent.substring(commaIndex + 1);
        final bytes = base64Decode(encoded);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child:
              Image.memory(bytes, width: 210, height: 160, fit: BoxFit.cover),
        );
      }
    }

    return Container(
      width: 210,
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: colorScheme.primary.withValues(alpha: 0.14),
      ),
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }
}
