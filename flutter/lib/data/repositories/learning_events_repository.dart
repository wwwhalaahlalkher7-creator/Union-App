import '../../core/network/api_client.dart';
import '../models/learning_event.dart';

class LearningEventsRepository {
  LearningEventsRepository(this._client);
  final ApiClient _client;

  Future<List<LearningEvent>> list() async {
    final json = await _client.getJson('/api/v1/learning-events');
    final raw = json['data'];
    return raw is List
        ? raw.whereType<Map>().map((e) => LearningEvent.fromJson(Map<String, dynamic>.from(e))).toList()
        : const [];
  }

  Future<LearningEvent> get(String id) async {
    final json = await _client.getJson('/api/v1/learning-events/$id');
    final data = json['data'];
    return LearningEvent.fromJson(data is Map ? Map<String, dynamic>.from(data) : const {});
  }

  Future<int> complete(String id) async {
    final json = await _client.postJson('/api/v1/learning-events/$id/complete', body: const {});
    final data = json['data'];
    return int.tryParse('${data is Map ? data['xpAwarded'] : 0}') ?? 0;
  }
}
