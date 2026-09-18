import '../../core/network/api_client.dart';
import '../models/content_item.dart';

class ContentRepository {
  ContentRepository(this._client);

  final ApiClient _client;

  Future<List<ContentItem>> news() => _list('/api/v1/public/news');

  Future<List<ContentItem>> announcements() =>
      _list('/api/v1/public/announcements');

  Future<List<ContentItem>> events() => _list('/api/v1/public/events');

  Future<List<ContentItem>> activities() =>
      _list('/api/v1/public/activities');

  Future<ContentItem> detail(String type, String id) async {
    final json = await _client.getJson('/api/v1/public/$type/$id', cacheTtl: const Duration(seconds: 20), forceRefresh: true);
    final data = json['data'];
    if (data is! Map) throw const ApiException('استجابة المحتوى غير صالحة.');
    return ContentItem.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<ContentItem>> achievements() =>
      _list('/api/v1/public/achievements');

  Future<List<ContentItem>> _list(String path) async {
    final json = await _client.getJson(
      path,
      cacheTtl: const Duration(seconds: 45),
    );
    final records = json['data'];
    if (records is! List) return const [];

    return records
        .whereType<Map>()
        .map((item) => ContentItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
