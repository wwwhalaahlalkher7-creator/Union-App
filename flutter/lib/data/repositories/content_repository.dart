import '../../core/network/api_client.dart';
import '../models/content_item.dart';
import 'repository_parser.dart';
import 'interactions_repository.dart';

class ContentRepository {
  ContentRepository(this._client);

  final ApiClient _client;

  Future<List<ContentItem>> news({bool forceRefresh = false, int offset = 0, int limit = 50}) =>
      _list('/api/v1/public/news', forceRefresh: forceRefresh, offset: offset, limit: limit);

  Future<List<ContentItem>> activities({bool forceRefresh = false, int offset = 0, int limit = 50}) =>
      _list('/api/v1/public/activities', forceRefresh: forceRefresh, offset: offset, limit: limit);

  Future<List<ContentItem>> achievements({bool forceRefresh = false, int offset = 0, int limit = 50}) =>
      _list('/api/v1/public/achievements', forceRefresh: forceRefresh, offset: offset, limit: limit);

  Future<ContentItem> detail(String type, String id) async {
    final json = await _client.getJson(
      '/api/v1/public/${_publicRoute(type)}/$id',
      cacheTtl: type == 'achievement' ? const Duration(hours: 24) : const Duration(hours: 12),
      forceRefresh: false,
    );
    return ContentItem.fromJson(RepositoryParser.map(json));
  }

  String _publicRoute(String type) => switch (type) {
        'activity' => 'activities',
        'achievement' => 'achievements',
        _ => type,
      };

  Future<List<ContentItem>> _list(
    String path, {
    required bool forceRefresh,
    required int offset,
    required int limit,
  }) async {
    // Flush queued final reaction states on the next content navigation after connectivity returns.
    await InteractionsRepository(_client).syncPendingReactions();
    final json = await _client.getJson(
      path,
      query: {'limit': '${limit.clamp(1, 50)}', 'offset': '${offset.clamp(0, 100000)}'},
      cacheTtl: path.endsWith('/achievements') ? const Duration(hours: 24) : const Duration(hours: 12),
      forceRefresh: forceRefresh,
    );
    return RepositoryParser.maps(json)
        .map(ContentItem.fromJson)
        .toList(growable: false);
  }
}
