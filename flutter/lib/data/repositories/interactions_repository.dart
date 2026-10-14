import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  String _queueKey(String scope) => 'trinex_pending_reactions_v1_$scope';

  Future<Map<String, dynamic>> _readReactionQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey(await _client.cacheScope));
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) { return <String, dynamic>{}; }
  }

  Future<void> _writeReactionQueue(Map<String, dynamic> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _queueKey(await _client.cacheScope);
    if (queue.isEmpty) { await prefs.remove(key); return; }
    await prefs.setString(key, jsonEncode(queue));
  }

  String _reactionQueueId(String type, String id) => '$type|$id';

  Future<void> syncPendingReactions({String? exceptQueueId}) async {
    Map<String, dynamic> queue;
    try { queue = await _readReactionQueue(); } catch (_) { return; }
    for (final entry in queue.entries.toList()) {
      if (entry.key == exceptQueueId || entry.value is! Map) continue;
      final item = Map<String, dynamic>.from(entry.value as Map);
      final type = '${item['type'] ?? ''}';
      final id = '${item['id'] ?? ''}';
      final reaction = item['reaction'];
      if (id.isEmpty) { queue.remove(entry.key); continue; }
      try {
        final path = type == 'comment'
            ? '/api/v1/comments/${Uri.encodeComponent(id)}/reactions'
            : '/api/v1/content/${Uri.encodeComponent(type)}/${Uri.encodeComponent(id)}/reactions';
        if (reaction == null) {
          await _client.deleteJson(path);
        } else {
          await _client.postJson(path, body: {'reaction': '$reaction'});
        }
        queue.remove(entry.key);
        await _writeReactionQueue(queue);
      } catch (_) {
        // Keep the desired final state; POST upserts and DELETE is idempotent.
      }
    }
  }

  Future<void> _setQueuedReaction({required String type, required String id, required String? reaction}) async {
    final queue = await _readReactionQueue();
    queue[_reactionQueueId(type, id)] = <String, dynamic>{'type': type, 'id': id, 'reaction': reaction, 'savedAt': DateTime.now().toUtc().toIso8601String()};
    await _writeReactionQueue(queue);
  }

  Future<void> _clearQueuedReaction(String type, String id) async {
    try {
      final queue = await _readReactionQueue();
      queue.remove(_reactionQueueId(type, id));
      await _writeReactionQueue(queue);
    } catch (_) {}
  }

  Future<CommentPage> commentsPage(
    String type,
    String id, {
    int offset = 0,
  }) async {
    await syncPendingReactions();
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
    await syncPendingReactions();
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

  Future<void> unreactComment(String commentId) async => _setReactionWithQueue(type: 'comment', id: commentId, reaction: null);

  Future<void> reactComment(String commentId, String reaction) async => _setReactionWithQueue(type: 'comment', id: commentId, reaction: reaction);

  Future<void> unreact(String type, String id) async => _setReactionWithQueue(type: type, id: id, reaction: null);

  Future<void> react(String type, String id, String reaction) async => _setReactionWithQueue(type: type, id: id, reaction: reaction);

  Future<void> _invalidateContentList(String type) async {
    switch (type) {
      case 'news':
        await _client.invalidateCacheForPath('/api/v1/public/news');
        break;
      case 'activity':
        await _client.invalidateCacheForPath('/api/v1/public/activities');
        break;
      case 'achievement':
        await _client.invalidateCacheForPath('/api/v1/public/achievements');
        break;
      default:
        // Comment reactions do not change public content list counts.
        break;
    }
  }

  Future<void> _setReactionWithQueue({required String type, required String id, required String? reaction}) async {
    await syncPendingReactions(exceptQueueId: _reactionQueueId(type, id));
    final path = type == 'comment'
        ? '/api/v1/comments/${Uri.encodeComponent(id)}/reactions'
        : '/api/v1/content/${Uri.encodeComponent(type)}/${Uri.encodeComponent(id)}/reactions';
    try {
      if (reaction == null) {
        await _client.deleteJson(path);
      } else {
        await _client.postJson(path, body: {'reaction': reaction});
      }
      await _clearQueuedReaction(type, id);
      await _invalidateContentList(type);
    } catch (error) {
      if (error is ApiException && error.retryable) {
        try { await _setQueuedReaction(type: type, id: id, reaction: reaction); } catch (_) {}
        await _invalidateContentList(type);
        return;
      }
      rethrow;
    }
  }

  Future<void> deleteComment(String id) async {
    await _client.deleteJson('/api/v1/comments/$id');
  }

  Future<void> deleteReply(String id) async {
    await _client.deleteJson('/api/v1/replies/$id');
  }
}

