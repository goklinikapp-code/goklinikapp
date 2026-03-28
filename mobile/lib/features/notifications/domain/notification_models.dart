class GKNotification {
  const GKNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  factory GKNotification.fromJson(Map<String, dynamic> json) {
    return GKNotification(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['notification_type'] ?? 'system').toString(),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse((json['created_at'] ?? json['sent_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
