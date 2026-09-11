import '../../core/network/api_client.dart';
import '../models/notification_item.dart';

class NotificationsRepository {
  NotificationsRepository(this._client);
  final ApiClient _client;

  Future<List<NotificationItem>> list() async {
    final json = await _client.getJson('/student/notifications');
    final data = json['data'];
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> markRead(Iterable<String> ids) async {
    final list = ids.where((id) => id.isNotEmpty).toList();
    if (list.isEmpty) return;
    await _client.postJson('/student/notifications/read', body: {'ids': list});
  }
}
