import '../../core/network/api_client.dart';
import '../models/badge_item.dart';
class BadgesRepository { BadgesRepository(this._client); final ApiClient _client; Future<BadgeSnapshot> getBadges() async { final j=await _client.getJson('/api/v1/badges'); final d=j['data']; return BadgeSnapshot.fromJson(d is Map?Map<String,dynamic>.from(d):const {}); } }
