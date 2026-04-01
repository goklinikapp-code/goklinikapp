import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
  bool get _isAiChat => widget.roomId == aiChatRoomId;

  static const _quickReplies = [
    'Tudo bem',
    'Sentindo dor',
    'Dúvida sobre remédio',
    'Posso dirigir?',
  ];

  @override
  void initState() {
    super.initState();
    if (!_isAiChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatMessagesProvider(widget.roomId).notifier).markRead();
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(chatMessagesProvider(widget.roomId).notifier)
          .send(content: text);
      _messageController.clear();
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

  Future<void> _sendImage() async {
    if (_isAiChat) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Neste canal, envie apenas mensagens de texto.'),
        ),
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
    return 'Não foi possível enviar sua mensagem agora.';
  }

  String _displayContent(String value) {
    var sanitized = value
        .replaceAll(
          RegExp(r'assistente\s+IA', caseSensitive: false),
          'atendimento da clínica',
        )
        .replaceAll(
          RegExp(r'\bIA\b', caseSensitive: false),
          'atendimento',
        )
        .replaceAll(
          'opção de dúvida urgente',
          'opção de mensagem para o médico',
        );

    return sanitized;
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(chatMessagesProvider(widget.roomId));
    final session = ref.watch(authControllerProvider).session;
    final tenantBranding = ref.watch(tenantBrandingProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final clinicName = tenantBranding.name.trim().isNotEmpty
        ? tenantBranding.name.trim()
        : 'Equipe da Clínica';
    final aiLogoUrl = (tenantBranding.logoUrl ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GKAvatar(
              name: _isAiChat ? clinicName : 'Equipe',
              imageUrl: _isAiChat && aiLogoUrl.isNotEmpty ? aiLogoUrl : null,
              radius: 18,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAiChat ? clinicName : 'Equipe da Clínica',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  _isAiChat ? 'ATENDIMENTO DIGITAL' : 'ONLINE',
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
              error: (error, _) => Center(child: Text('Erro no chat: $error')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                      child: Text(
                          'Conversa iniciada. Envie sua primeira mensagem.'));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final message = items[index];
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
                                style: TextStyle(
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
                        hintText: 'Digite sua mensagem',
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
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
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
