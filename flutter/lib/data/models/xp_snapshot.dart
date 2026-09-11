class XpSnapshot {
  const XpSnapshot({required this.totalXp, required this.level, required this.levelXp, required this.nextLevelXp, required this.events});
  final int totalXp, level, levelXp, nextLevelXp;
  final List<XpEvent> events;

  factory XpSnapshot.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] is Map ? Map<String, dynamic>.from(json['stats']) : <String, dynamic>{};
    final raw = json['events'];
    return XpSnapshot(
      totalXp: int.tryParse('${stats['xp_total'] ?? stats['xpTotal'] ?? 0}') ?? 0,
      level: int.tryParse('${stats['level'] ?? 1}') ?? 1,
      levelXp: int.tryParse('${stats['level_xp'] ?? stats['levelXp'] ?? 0}') ?? 0,
      nextLevelXp: int.tryParse('${stats['next_level_xp'] ?? stats['nextLevelXp'] ?? 100}') ?? 100,
      events: raw is List ? raw.whereType<Map>().map((e) => XpEvent.fromJson(Map<String, dynamic>.from(e))).toList() : const [],
    );
  }
}

class XpEvent {
  const XpEvent({required this.type, required this.sourceId, required this.xp, required this.createdAt});
  final String type; final String? sourceId; final int xp; final String createdAt;
  factory XpEvent.fromJson(Map<String,dynamic> j) => XpEvent(
    type: '${j['event_type'] ?? j['eventType'] ?? ''}', sourceId: j['source_id']?.toString(),
    xp: int.tryParse('${j['xp'] ?? 0}') ?? 0, createdAt: '${j['created_at'] ?? j['createdAt'] ?? ''}',
  );
}
