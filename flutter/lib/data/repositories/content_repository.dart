import '../../core/network/api_client.dart';
import '../models/content_item.dart';
import 'repository_parser.dart';

class ContentRepository {
  ContentRepository(this._client);

  final ApiClient _client;

  Future<List<ContentItem>> news({bool forceRefresh = false}) =>
      _list('/api/v1/public/news', forceRefresh: forceRefresh);

  Future<List<ContentItem>> events({bool forceRefresh = false}) =>
      _list('/api/v1/public/events', forceRefresh: forceRefresh);

  Future<List<ContentItem>> achievements({bool forceRefresh = false}) =>
      _list('/api/v1/public/achievements', forceRefresh: forceRefresh);

  Future<ContentItem> detail(String type, String id) async {
    final json = await _client.getJson(
      '/api/v1/public/${_publicRoute(type)}/$id',
      cacheTtl: const Duration(seconds: 20),
      forceRefresh: true,
    );
    return ContentItem.fromJson(RepositoryParser.map(json));
  }

  String _publicRoute(String type) => switch (type) {
        'event' => 'events',
        'achievement' => 'achievements',
        _ => type,
      };

  Future<List<ContentItem>> _list(
    String path, {
    required bool forceRefresh,
  }) async {
    final json = await _client.getJson(
      path,
      cacheTtl: const Duration(seconds: 45),
      forceRefresh: forceRefresh,
    );
    return RepositoryParser.maps(json)
        .map(ContentItem.fromJson)
        .toList(growable: false);
  }
}
