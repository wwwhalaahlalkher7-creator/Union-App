import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../models/content_item.dart';

class ContentRepository {
  Future<List<ContentItem>> news({bool forceRefresh = false}) => _list('/api/v1/public/news', forceRefresh: forceRefresh);
  Future<List<ContentItem>> events({bool forceRefresh = false}) => _list('/api/v1/public/events', forceRefresh: forceRefresh);
  Future<List<ContentItem>> achievements({bool forceRefresh = false}) => _list('/api/v1/public/achievements', forceRefresh: forceRefresh);

  Future<ContentItem> detail(String type, String id) async {
    final client = await AuthenticatedClient.create();
    try {
      final json = await client.getJson(
        '/api/v1/public/${_publicRoute(type)}/$id',
        cacheTtl: const Duration(seconds: 20),
        forceRefresh: true,
      );
      final data = json['data'];
      if (data is! Map) throw const ApiException('استجابة المحتوى غير صالحة.');
      return ContentItem.fromJson(Map<String, dynamic>.from(data));
    } finally {
      client.dispose();
    }
  }

  String _publicRoute(String type) => type == 'event' ? 'events' : type == 'achievement' ? 'achievements' : type;

  Future<List<ContentItem>> _list(String path, {bool forceRefresh = false}) async {
    final client = await AuthenticatedClient.create();
    try {
      final json = await client.getJson(
        path,
        cacheTtl: const Duration(seconds: 45),
        forceRefresh: forceRefresh,
      );
      final records = json['data'];
      if (records is! List) return const [];
      return records
          .whereType<Map>()
          .map((item) => ContentItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } finally {
      client.dispose();
    }
  }
}
