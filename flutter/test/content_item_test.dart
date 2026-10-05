import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/data/models/content_item.dart';

void main() {
  test('parses achievement classification and event end date', () {
    final achievement = ContentItem.fromJson({
      'id': 'a1',
      'title': 'دفعة مميزة',
      'description': 'وصف الإنجاز',
      'badge': 'إنجاز تاريخي',
      'commentCount': 3,
      'likeCount': 5,
    });
    expect(achievement.badge, 'إنجاز تاريخي');
    expect(achievement.body, 'وصف الإنجاز');
    expect(achievement.commentCount, 3);
    expect(achievement.likeCount, 5);

    final event = ContentItem.fromJson({
      'id': 'e1',
      'title': 'فعالية',
      'eventAt': '2026-10-05T10:00:00Z',
      'endAt': '2026-10-05T14:00:00Z',
    });
    expect(event.eventAt, isNotNull);
    expect(event.endAt, isNotNull);
    expect(event.endAt!.isAfter(event.eventAt!), isTrue);
  });
}
