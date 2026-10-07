import '../../core/network/api_client.dart';
import 'repository_parser.dart';
import '../models/comment_item.dart';

class CommentPage {
  const CommentPage({required this.items, required this.total});
  final List<CommentItem> items;
  final int total;
}

class InteractionsRepository {
  InteractionsRepository(this._client);

  final ApiClient _client;

  Future<CommentPage> commentsPage(
    String type,
    String id, {
    int offset = 0,
  }) async {
    final json = await _client.getJson(
      '/api/v1/content/$type/$id/comments',
      query: {'limit': '20', 'offset': '$offset'},
    );
    final items = RepositoryParser.maps(json)
        .map(CommentItem.fromJson)
        .toList(growable: false);
    return CommentPage(items: items, total: RepositoryParser.integer(json['meta'] is Map ? (json['meta'] as Map)['total'] : json['total'], fallback: items.length));
  }

  Future<List<CommentItem>> comments(
    String type,
    String id, {
    int offset = 0,
  }) async => (await commentsPage(type, id, offset: offset)).items;

  Future<List<CommentItem>> replies(String id, {int offset = 0}) async {
    final json = await _client.getJson(
      '/api/v1/comments/$id/replies',
      query: {'limit': '50', 'offset': '$offset'},
    );
    return RepositoryParser.maps(json)
        .map(CommentItem.fromJson)
        .toList(growable: false);
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

  Future<void> unreactComment(String commentId) async {
    await _client.deleteJson('/api/v1/comments/$commentId/reactions');
  }

  Future<void> reactComment(String commentId, String reaction) async {
    await _client.postJson(
      '/api/v1/comments/$commentId/reactions',
      body: {'reaction': reaction},
    );
  }

  Future<void> unreact(String type, String id) async {
    await _client.deleteJson('/api/v1/content/$type/$id/reactions');
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

