import '../../core/network/api_client.dart';
import '../models/comment_item.dart';

class InteractionsRepository {
  InteractionsRepository(this._client);

  final ApiClient _client;

  Future<List<CommentItem>> comments(
    String type,
    String id, {
    int offset = 0,
  }) async {
    final json = await _client.getJson(
      '/api/v1/content/$type/$id/comments',
      query: {'limit': '20', 'offset': '$offset'},
    );
    final rows = json['data'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => CommentItem.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<CommentItem>> replies(String id, {int offset = 0}) async {
    final json = await _client.getJson(
      '/api/v1/comments/$id/replies',
      query: {'limit': '20', 'offset': '$offset'},
    );
    final rows = json['data'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => CommentItem.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> addComment(String type, String id, String body) async {
    await _client.postJson(
      '/api/v1/content/$type/$id/comments',
      body: {'body': body},
    );
  }

  Future<void> addReply(String id, String body) async {
    await _client.postJson(
      '/api/v1/comments/$id/replies',
      body: {'body': body},
    );
  }

  Future<void> reactComment(String commentId, String reaction) async {
    await _client.postJson(
      '/api/v1/comments/$commentId/reactions',
      body: {'reaction': reaction},
    );
  }

  Future<void> react(String type, String id, String reaction) async {
    await _client.postJson(
      '/api/v1/content/$type/$id/reactions',
      body: {'reaction': reaction},
    );
  }

  Future<void> deleteComment(String id) async {
    await _client.deleteJson('/api/v1/comments/$id');
  }
}
