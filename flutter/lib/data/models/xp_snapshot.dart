class XpSnapshot {
  const XpSnapshot({
    required this.totalXp,
    required this.level,
    required this.levelXp,
    required this.nextLevelXp,
  });

  final int totalXp;
  final int level;
  final int levelXp;
  final int nextLevelXp;

  factory XpSnapshot.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] is Map
        ? Map<String, dynamic>.from(json['stats'])
        : <String, dynamic>{};
    return XpSnapshot(
      totalXp: int.tryParse('${stats['xp_total'] ?? stats['xpTotal'] ?? 0}') ?? 0,
      level: int.tryParse('${stats['level'] ?? 1}') ?? 1,
      levelXp: int.tryParse('${stats['level_xp'] ?? stats['levelXp'] ?? 0}') ?? 0,
      nextLevelXp: int.tryParse('${stats['next_level_xp'] ?? stats['nextLevelXp'] ?? 100}') ?? 100,
    );
  }
}
