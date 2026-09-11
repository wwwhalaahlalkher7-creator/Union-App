import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/content_item.dart';

class ContentRepository {
  ContentRepository(this._client);

  final ApiClient _client;

  Future<List<ContentItem>> news() => _list(AppConstants.newsAction);

  Future<List<ContentItem>> announcements() =>
      _list(AppConstants.announcementsAction);

  Future<List<ContentItem>> activities() =>
      _list(AppConstants.activitiesAction);

  Future<List<ContentItem>> achievements() =>
      _list(AppConstants.achievementsAction);

  Future<List<ContentItem>> _list(String action) async {
    final json = await _client.getJson(
      '',
      query: {'action': action},
      cacheTtl: const Duration(seconds: 45),
    );
    final records = json['records'] ?? json['data'] ?? [];
    if (records is! List) return const [];

    return records
        .whereType<Map>()
        .map((item) => ContentItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
