import '../../core/network/api_client.dart';
import '../models/badge_item.dart';
import 'repository_parser.dart';

class BadgesRepository {
  BadgesRepository(this._client);

  final ApiClient _client;

  Future<BadgeSnapshot> getBadges() async {
    final json = await _client.getJson('/api/v1/badges');
    return BadgeSnapshot.fromJson(RepositoryParser.map(json));
  }
}
