import '../../core/network/api_client.dart';
import '../models/notification_item.dart';
import 'repository_parser.dart';

class NotificationsRepository {
  NotificationsRepository(this._client);
  final ApiClient _client;

  Future<List<NotificationItem>> list() async {
    final json = await _client.getJson('/api/v1/student/notifications');
    return RepositoryParser.maps(json)
        .map(NotificationItem.fromJson)
        .toList(growable: false);
  }

  Future<void> delete(String id) async {
    await _client.deleteJson('/api/v1/student/notifications/${Uri.encodeComponent(id)}');
  }

  Future<void> markRead(Iterable<String> ids) async {
    final list = ids.where((id) => id.isNotEmpty).toList(growable: false);
    if (list.isEmpty) return;
    await _client.postJson(
      '/api/v1/student/notifications/read',
      body: {'ids': list},
    );
  }
}
