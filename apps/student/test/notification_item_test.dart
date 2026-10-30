import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/data/models/notification_item.dart';

void main() {
  test('notification model preserves normalized publication and expiry timestamps', () {
    final item = NotificationItem.fromJson({
      'id': 'notice-1',
      'title': 'موعد مهم',
      'body': 'سيبدأ لاحقًا',
      'type': 'general',
      'read_at': null,
      'publish_at': '2026-10-20T15:30:00.000Z',
      'expires_at': '2026-10-22T13:00:00.000Z',
    });

    expect(item.publishAt, '2026-10-20T15:30:00.000Z');
    expect(item.expiresAt, '2026-10-22T13:00:00.000Z');
    expect(item.isRead, isFalse);
  });
}
