class BadgeItem {
  const BadgeItem({required this.id, required this.name, required this.description, required this.ruleType, required this.ruleValue, required this.earned, this.iconUrl, this.awardedAt, this.nameEn, this.nameFr, this.descriptionEn, this.descriptionFr});

  final String id, name, description, ruleType;
  final int ruleValue;
  final bool earned;
  final String? iconUrl, awardedAt, nameEn, nameFr, descriptionEn, descriptionFr;

  factory BadgeItem.fromJson(Map<String, dynamic> j) => BadgeItem(
    id: '${j['id'] ?? ''}',
    name: '${j['name_ar'] ?? j['name'] ?? 'Badge'}',
    description: '${j['description_ar'] ?? j['description'] ?? ''}',
    ruleType: '${j['rule_type'] ?? ''}',
    ruleValue: int.tryParse('${j['rule_value'] ?? 0}') ?? 0,
    earned: j['earned'] == true || '${j['earned'] ?? 0}' == '1',
    iconUrl: j['icon_url']?.toString(),
    awardedAt: j['awarded_at']?.toString(),
    nameEn: j['name_en']?.toString(),
    nameFr: j['name_fr']?.toString(),
    descriptionEn: j['description_en']?.toString(),
    descriptionFr: j['description_fr']?.toString(),
  );

  String localizedName(String languageCode) => switch (languageCode) {
    'en' => nameEn?.trim().isNotEmpty == true ? nameEn! : name,
    'fr' => nameFr?.trim().isNotEmpty == true ? nameFr! : name,
    _ => name,
  };

  String localizedDescription(String languageCode) => switch (languageCode) {
    'en' => descriptionEn?.trim().isNotEmpty == true ? descriptionEn! : description,
    'fr' => descriptionFr?.trim().isNotEmpty == true ? descriptionFr! : description,
    _ => description,
  };
}

class BadgeCategory {
  const BadgeCategory({
    required this.key,
    required this.name,
    required this.icon,
    required this.unlimited,
    required this.current,
    required this.completed,
    required this.earnedCount,
    this.max,
    this.next,
  });

  final String key, name, icon;
  final bool unlimited, completed;
  final int current, earnedCount;
  final int? max;
  final BadgeItem? next;

  factory BadgeCategory.fromJson(Map<String, dynamic> j) {
    final rawNext = j['next'];
    return BadgeCategory(
      key: '${j['key'] ?? ''}',
      name: '${j['name_ar'] ?? j['name'] ?? ''}',
      icon: '${j['icon'] ?? 'workspace_premium'}',
      unlimited: j['unlimited'] == true || '${j['unlimited'] ?? 0}' == '1',
      current: int.tryParse('${j['current'] ?? 0}') ?? 0,
      earnedCount: int.tryParse('${j['earnedCount'] ?? 0}') ?? 0,
      completed: j['completed'] == true || '${j['completed'] ?? 0}' == '1',
      max: j['max'] == null ? null : int.tryParse('${j['max']}'),
      next: rawNext is Map ? BadgeItem.fromJson(Map<String, dynamic>.from(rawNext)) : null,
    );
  }

  int get target => next?.ruleValue ?? max ?? current;
  int get remaining => completed ? 0 : (target - current).clamp(0, target);
  double get progress {
    if (completed || target <= 0) return 1.0;
    return (current / target).clamp(0.0, 1.0).toDouble();
  }
}

class BadgeSnapshot {
  const BadgeSnapshot({required this.badges, required this.categories, required this.earnedCount, required this.totalCount, required this.newlyAwarded});
  final List<BadgeItem> badges;
  final List<BadgeCategory> categories;
  final int earnedCount, totalCount;
  final List<String> newlyAwarded;

  factory BadgeSnapshot.fromJson(Map<String, dynamic> j) {
    final raw = j['badges'];
    final rawCategories = j['categories'];
    return BadgeSnapshot(
      badges: raw is List ? raw.whereType<Map>().map((e) => BadgeItem.fromJson(Map<String, dynamic>.from(e))).toList() : const [],
      categories: rawCategories is List ? rawCategories.whereType<Map>().map((e) => BadgeCategory.fromJson(Map<String, dynamic>.from(e))).toList() : const [],
      earnedCount: int.tryParse('${j['earnedCount'] ?? 0}') ?? 0,
      totalCount: int.tryParse('${j['totalCount'] ?? 0}') ?? 0,
      newlyAwarded: j['newlyAwarded'] is List ? j['newlyAwarded'].map((e) => e.toString()).toList() : const [],
    );
  }
}
