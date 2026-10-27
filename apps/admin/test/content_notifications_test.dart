import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinex_admin/src/api_service.dart';
import 'package:trinex_admin/src/features/content/content_page.dart';
import 'package:trinex_admin/src/features/notifications/notifications_page.dart';
import 'package:trinex_admin/src/session_store.dart';

class _FakeApi extends ApiService {
  _FakeApi() : super(sessionStore: SessionStore());

  final List<String> getCalls = [];
  final List<MapEntry<String, Map<String, dynamic>?>> postCalls = [];
  final List<MapEntry<String, Map<String, dynamic>?>> patchCalls = [];
  final List<String> deleteCalls = [];
  List<Map<String, dynamic>> notificationRows = [];

  @override
  Future<Map<String, dynamic>> get(String path) async {
    getCalls.add(path);
    if (path.startsWith('/admin/notifications')) {
      return {'data': notificationRows};
    }
    return {'data': <Map<String, dynamic>>[]};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    postCalls.add(MapEntry(path, body));
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    patchCalls.add(MapEntry(path, body));
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> delete(String path) async {
    deleteCalls.add(path);
    return {'success': true};
  }
}

void main() {
  testWidgets('content sections request the endpoint of the selected button',
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContentPage(api: api, role: 'super_admin'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(api.getCalls, contains('/admin/news?limit=100'));

    await tester.tap(find.text('الإنجازات').first);
    await tester.pumpAndSettle();
    expect(api.getCalls.last, '/admin/achievements?limit=100');

    await tester.tap(find.text('الأنشطة').first);
    await tester.pumpAndSettle();
    expect(api.getCalls.last, '/admin/activities?limit=100');
  });

  testWidgets('notifications screen publishes immediately without exposing a type selector',
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NotificationsPage(api: api)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إنشاء إشعار').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'اختبار إشعار');
    await tester.enterText(find.byType(TextFormField).at(1), 'هذا نص تجريبي للإشعار');
    await tester.tap(find.text('حفظ').last);
    await tester.pumpAndSettle();

    expect(api.postCalls, hasLength(1));
    expect(api.postCalls.single.key, '/admin/announcements');
    expect(api.postCalls.single.value?['title'], 'اختبار إشعار');
    expect(api.postCalls.single.value?['status'], 'published');
    expect(api.postCalls.single.value?['type'], 'general');
    expect(find.textContaining('النوع (مثال:'), findsNothing);
    expect(find.text('المسودات'), findsNothing);
    expect(find.text('المستهدفون'), findsNothing);
    expect(find.text('القراءات'), findsNothing);
  });

  testWidgets('future notification dates are shown in readable local date-time format',
      (tester) async {
    final api = _FakeApi()
      ..notificationRows = [
        {
          'id': 'scheduled-1',
          'title': 'إشعار مجدول',
          'body': 'سيظهر لاحقًا',
          'type': 'general',
          'status': 'published',
          'publish_at': '2099-10-18T17:45:00',
          'expires_at': '2099-10-20T18:15:00',
        },
      ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NotificationsPage(api: api)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('مجدول'), findsOneWidget);
    expect(find.text('18/10/2099  17:45'), findsOneWidget);
    expect(find.text('20/10/2099  18:15'), findsOneWidget);
    expect(find.textContaining('النوع (مثال:'), findsNothing);
  });

  testWidgets('only schedule/material-generated drafts expose approval action',
      (tester) async {
    final api = _FakeApi()
      ..notificationRows = [
        {
          'id': 'schedule-draft',
          'title': 'تحديث جدول',
          'body': 'تم تعديل جدول دراسي',
          'type': 'schedule',
          'content_type': 'schedule',
          'status': 'draft',
        },
      ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NotificationsPage(api: api)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('مرتبط بتحديث أكاديمي'), findsOneWidget);
    expect(find.text('اعتماد ونشر'), findsOneWidget);
  });
}

