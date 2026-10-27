class NotificationItem {
  const NotificationItem({required this.id, required this.title, required this.body, required this.type, required this.readAt, this.publishAt});
  final String id;
  final String title;
  final String body;
  final String type;
  final String? readAt;
  final String? publishAt;
  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    body: '${json['body'] ?? ''}',
    type: '${json['type'] ?? 'general'}',
    readAt: json['read_at']?.toString(),
    publishAt: json['publish_at']?.toString(),
  );
}
