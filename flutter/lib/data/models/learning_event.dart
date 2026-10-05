class LearningEvent {
  const LearningEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.design,
    required this.xpReward,
    required this.completed,
    this.config = const {},
    this.publishAt,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String description;
  final String design;
  final int xpReward;
  final bool completed;
  final Map<String, dynamic> config;
  final String? publishAt;
  final String? expiresAt;

  factory LearningEvent.fromJson(Map<String, dynamic> json) => LearningEvent(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    description: '${json['description'] ?? ''}',
    design: '${json['design'] ?? 'standard'}',
    xpReward: int.tryParse('${json['xp_reward'] ?? json['xpReward'] ?? 0}') ?? 0,
    completed: json['completed'] == true || json['completed'] == 1,
    config: json['config'] is Map ? Map<String, dynamic>.from(json['config']) : const {},
    publishAt: (json['publish_at'] ?? json['publishAt'])?.toString(),
    expiresAt: (json['expires_at'] ?? json['expiresAt'])?.toString(),
  );
}
