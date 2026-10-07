import '../../core/network/api_client.dart';
import '../models/learning_event.dart';
import 'repository_parser.dart';

class LearningEventsRepository {
  LearningEventsRepository(this._client);
  final ApiClient _client;

  Future<List<LearningEvent>> list() async {
    final json = await _client.getJson('/api/v1/learning-events');
    return RepositoryParser.maps(json)
        .map(LearningEvent.fromJson)
        .toList(growable: false);
  }

  Future<LearningEvent> get(String id) async {
    final json = await _client.getJson('/api/v1/learning-events/$id');
    return LearningEvent.fromJson(RepositoryParser.map(json));
  }

  Future<int> complete(String id) async {
    final json = await _client.postJson(
      '/api/v1/learning-events/$id/complete',
      body: const {},
    );
    final data = RepositoryParser.map(json);
    return RepositoryParser.integer(data['xpAwarded']);
  }
}
