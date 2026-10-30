import '../../core/network/api_client.dart';
import 'repository_parser.dart';

class FeedbackRepository {
  FeedbackRepository(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> submit({
    required String category,
    required String title,
    required String details,
    String? screen,
  }) async {
    final json = await _client.postJson('/api/v1/feedback', body: {
      'category': category,
      'title': title.trim(),
      'details': details.trim(),
      if (screen != null && screen.trim().isNotEmpty) 'screen': screen.trim(),
    });
    return RepositoryParser.map(json);
  }
}
