class NotificationItem {
  const NotificationItem({required this.id, required this.title, required this.body, required this.type, required this.readAt, this.publishAt, this.learningEventId, this.learningEventXp = 0});
  final String id;
  final String title;
  final String body;
  final String type;
  final String? readAt;
  final String? publishAt;
  final String? learningEventId;
  final int learningEventXp;
  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    body: '${json['body'] ?? ''}',
    type: '${json['type'] ?? 'general'}',
    readAt: json['read_at']?.toString(),
    publishAt: json['publish_at']?.toString(),
    learningEventId: json['learning_event_id']?.toString(),
    learningEventXp: int.tryParse('${json['learning_event_xp'] ?? 0}') ?? 0,
  );
}
