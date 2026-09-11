import '../../core/network/api_client.dart';
import '../models/xp_snapshot.dart';

class XpRepository {
  XpRepository(this._client);
  final ApiClient _client;

  Future<XpSnapshot> getXp() async {
    final json = await _client.getJson('/api/v1/xp');
    final data = json['data'];
    return XpSnapshot.fromJson(data is Map ? Map<String, dynamic>.from(data) : const {});
  }
}
