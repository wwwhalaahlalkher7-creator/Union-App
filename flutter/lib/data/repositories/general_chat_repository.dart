import '../../core/network/api_client.dart';
import 'repository_parser.dart';

class GeneralChatRepository {
  GeneralChatRepository(this._client);
  final ApiClient _client;

  Future<List<Map<String, dynamic>>> messages({int limit = 50}) async {
    final response = await _client.getJson('/api/v1/chat/messages', query: {'limit': '$limit'}, forceRefresh: true);
    return RepositoryParser.maps(response);
  }

  Future<Map<String, dynamic>> send(String body, {String? replyToMessageId}) async {
    final response = await _client.postJson('/api/v1/chat/messages', body: {
      'body': body,
      if (replyToMessageId != null && replyToMessageId.trim().isNotEmpty) 'replyToMessageId': replyToMessageId.trim(),
    });
    return RepositoryParser.map(response);
  }

  Future<void> delete(String id) async {
    await _client.deleteJson('/api/v1/chat/messages/${Uri.encodeComponent(id)}');
  }

  Future<void> report(String id, {required String reason, String? details}) async {
    await _client.postJson('/api/v1/chat/messages/${Uri.encodeComponent(id)}/report', body: {
      'reason': reason,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    });
  }
}
