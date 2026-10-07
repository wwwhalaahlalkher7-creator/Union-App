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
    BadgeItem nextXp;
    if (xp.totalXp < 50) {
      nextXp = const BadgeItem(id: 'badge-xp-50', name: 'أول دفعة', description: 'اجمع 50 XP.', ruleType: 'xp_total', ruleValue: 50, earned: false);
    } else if (xp.totalXp < 100) {
      nextXp = const BadgeItem(id: 'badge-xp-100', name: 'مئة XP', description: 'اجمع 100 XP.', ruleType: 'xp_total', ruleValue: 100, earned: false);
    } else if (xp.totalXp < 250) {
      nextXp = const BadgeItem(id: 'badge-xp-250', name: 'ربع ألف XP', description: 'اجمع 250 XP.', ruleType: 'xp_total', ruleValue: 250, earned: false);
    } else if (xp.totalXp < 500) {
      nextXp = const BadgeItem(id: 'badge-xp-500', name: '500 XP', description: 'اجمع 500 XP.', ruleType: 'xp_total', ruleValue: 500, earned: false);
    } else {
      final target = xp.totalXp < 1000 ? 1000 : xp.totalXp < 2000 ? 2000 : xp.totalXp < 5000 ? 5000 : xp.totalXp * 2;
      nextXp = BadgeItem(id: 'badge-xp-$target', name: '$target XP', description: 'اجمع $target XP.', ruleType: 'xp_total', ruleValue: target, earned: false);
    }
    final nextLevel = xp.level + 1;
    final levelBadge = BadgeItem(id: 'badge-level-$nextLevel', name: 'المستوى $nextLevel', description: 'وصل إلى المستوى $nextLevel.', ruleType: 'level', ruleValue: nextLevel, earned: false);
    final categories = <BadgeCategory>[
      BadgeCategory(key: 'xp_total', name: 'XP', icon: 'bolt', unlimited: true, current: xp.totalXp, earnedCount: 0, completed: false, next: nextXp),
      BadgeCategory(key: 'level', name: 'المستويات', icon: 'trending_up', unlimited: true, current: xp.level, earnedCount: 0, completed: false, next: levelBadge),
    ];
    return BadgeSnapshot(badges: const [], categories: categories, earnedCount: 0, totalCount: categories.length, newlyAwarded: const []);
  }

  Future<BadgeSnapshot> getBadges() async {
    final json = await _client.getJson('/api/v1/badges');
    return BadgeSnapshot.fromJson(RepositoryParser.map(json));
  }
}
