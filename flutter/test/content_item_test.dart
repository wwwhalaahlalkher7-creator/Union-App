import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/data/models/content_item.dart';

void main() {
  test('uses dashboard publish and achievement dates and category fields', () {
    final news = ContentItem.fromJson({
      'id': 'n1', 'title': 'خبر', 'publishAt': '2026-10-18T00:00:00+02:00',
      'category': 'statement',
    });
    expect(news.eventAt, isNotNull);
    expect(news.category, 'statement');

    final achievement = ContentItem.fromJson({
      'id': 'a2', 'title': 'إنجاز', 'achieved_at': '2026-10-17',
      'badge': 'أكاديمي', 'images_json': '["https://cdn.example/a.jpg","https://cdn.example/b.jpg"]',
    });
    expect(achievement.eventAt, isNotNull);
    expect(achievement.category, 'أكاديمي');
    expect(achievement.images, hasLength(2));
    expect(achievement.imageUrl, 'https://cdn.example/a.jpg');
  });

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
