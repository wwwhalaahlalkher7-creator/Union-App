class NotificationItem {
  const NotificationItem({required this.id, required this.title, required this.body, required this.type, required this.readAt, this.publishAt, this.expiresAt, this.category = 'general', this.contentType, this.contentId});
  final String id;
  final String title;
  final String body;
  final String type;
  final String? readAt;
  final String? publishAt;
  final String? expiresAt;
  final String category;
  final String? contentType;
  final String? contentId;
  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    body: '${json['body'] ?? ''}',
    type: '${json['type'] ?? 'general'}',
    readAt: json['read_at']?.toString(),
    publishAt: json['publish_at']?.toString(),
    expiresAt: json['expires_at']?.toString(),
    category: '${json['notification_category'] ?? json['type'] ?? 'general'}',
    contentType: json['content_type']?.toString(),
    contentId: json['content_id']?.toString(),
  );
}
