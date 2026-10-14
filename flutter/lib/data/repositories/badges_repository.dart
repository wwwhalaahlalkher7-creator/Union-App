import '../../core/network/api_client.dart';
import '../models/badge_item.dart';
import '../models/xp_snapshot.dart';
import 'repository_parser.dart';

class BadgesRepository {
  BadgesRepository(this._client);

  final ApiClient _client;


  /// Local safety-net used when the badges endpoint is unavailable. Badge
  /// definitions are application-owned, so the XP screen must never become
  /// unusable just because the optional badge metrics request failed.
  static BadgeSnapshot fallbackForXp(XpSnapshot xp) {
    final totalXp = xp.totalXp;
    final nextXp = _nextXpThreshold(totalXp);
    final nextLevel = xp.level + 1;

    final earned = <BadgeItem>[];
    const xpThresholds = <int>[50, 100, 250, 500, 1000, 2000, 5000];
    for (final threshold in xpThresholds) {
      if (totalXp >= threshold) {
        earned.add(BadgeItem(
          id: 'badge-xp-$threshold',
          name: '$threshold XP',
          description: 'اجمع $threshold XP.',
          ruleType: 'xp_total',
          ruleValue: threshold,
          earned: true,
        ));
      }
    }
    const levelThresholds = <int>[2, 3, 5, 10, 15];
    for (final threshold in levelThresholds) {
      if (xp.level >= threshold) {
        earned.add(BadgeItem(
          id: 'badge-level-$threshold',
          name: 'المستوى $threshold',
          description: 'وصل إلى المستوى $threshold.',
          ruleType: 'level',
          ruleValue: threshold,
          earned: true,
        ));
      }
    }

    // Deliberately keep the local fallback minimal. The full badge catalogue
    // must come from the backend so that this fallback also helps us detect
    // an incomplete/failed badges deployment during testing.
    final categories = <BadgeCategory>[
      BadgeCategory(
        key: 'xp_total',
        name: 'XP',
        icon: 'bolt',
        unlimited: true,
        current: totalXp,
        earnedCount: earned.where((b) => b.ruleType == 'xp_total').length,
        completed: false,
        next: BadgeItem(
          id: 'badge-xp-$nextXp',
          name: '$nextXp XP',
          description: 'اجمع $nextXp XP.',
          ruleType: 'xp_total',
          ruleValue: nextXp,
          earned: false,
        ),
      ),
      BadgeCategory(
        key: 'level',
        name: 'المستويات',
        icon: 'trending_up',
        unlimited: true,
        current: xp.level,
        earnedCount: earned.where((b) => b.ruleType == 'level').length,
        completed: false,
        next: BadgeItem(
          id: 'badge-level-$nextLevel',
          name: 'المستوى $nextLevel',
          description: 'وصل إلى المستوى $nextLevel.',
          ruleType: 'level',
          ruleValue: nextLevel,
          earned: false,
        ),
      ),
    ];

    return BadgeSnapshot(
      badges: earned,
      categories: categories,
      earnedCount: earned.length,
      totalCount: earned.length + categories.length,
      newlyAwarded: const [],
    );
  }

  static int _nextXpThreshold(int current) {
    const fixed = <int>[50, 100, 250, 500, 1000, 2000, 5000];
    for (final value in fixed) {
      if (current < value) return value;
    }
    var value = 10000;
    while (value <= current) {
      value *= 2;
    }
    return value;
  }

  Future<BadgeSnapshot> getBadges() async {
    final json = await _client.getJson('/api/v1/badges');
    return BadgeSnapshot.fromJson(RepositoryParser.map(json));
  }
}
