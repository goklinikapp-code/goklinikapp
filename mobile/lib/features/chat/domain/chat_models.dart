import '../../../core/utils/api_media_url.dart';
import '../../../core/utils/text_normalizer.dart';

class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.roomType,
    required this.interlocutorName,
    required this.interlocutorAvatar,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String id;
  final String roomType;
  final String interlocutorName;
  final String interlocutorAvatar;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: (json['id'] ?? '').toString(),
      roomType: (json['room_type'] ?? '').toString(),
      interlocutorName: normalizeApiText(json['interlocutor_name']),
      interlocutorAvatar: resolveApiMediaUrl(
        (json['interlocutor_avatar'] ?? '').toString(),
      ),
      lastMessagePreview: normalizeApiText(json['last_message_preview']),
      lastMessageAt:
          DateTime.tryParse((json['last_message_at'] ?? '').toString()),
      unreadCount: int.tryParse((json['unread_count'] ?? 0).toString()) ?? 0,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.content,
    required this.messageType,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final String messageType;
  final bool isRead;
  final DateTime createdAt;

  bool get isImage => messageType == 'image';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender =
        (json['sender'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final messageType = (json['message_type'] ?? 'text').toString();
    final rawContent = (json['content'] ?? '').toString();
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      senderId: (sender['id'] ?? '').toString(),
      senderName: normalizeApiText(sender['name']),
      senderAvatar: resolveApiMediaUrl((sender['avatar'] ?? '').toString()),
      content: messageType == 'image'
          ? resolveApiMediaUrl(rawContent)
          : normalizeApiText(rawContent),
      messageType: messageType,
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  factory ChatMessage.fromAiJson(Map<String, dynamic> json) {
    final role = (json['role'] ?? '').toString();
    final isUser = role == 'user';
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      senderId: isUser ? 'user' : 'assistant',
      senderName: isUser ? 'Você' : 'Equipe da Clínica',
      senderAvatar: '',
      content: normalizeApiText(json['content']),
      messageType: 'text',
      isRead: true,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
