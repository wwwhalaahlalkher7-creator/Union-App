import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trinex_admin/src/api_service.dart';
import 'package:trinex_admin/src/session_store.dart';

class MemorySessionStore extends SessionStore {
  AdminSession? value;

  MemorySessionStore([this.value]);

  @override
  Future<AdminSession?> readIncludingExpired() async => value;

  @override
  Future<AdminSession?> read() async => value?.isExpired == true ? null : value;

  @override
  Future<void> save(AdminSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

AdminSession session({
  String access = 'access-1',
  String refresh = 'refresh-1',
  Duration lifetime = const Duration(minutes: 10),
}) => AdminSession(
      accessToken: access,
      refreshToken: refresh,
      displayName: 'مشرف الاختبار',
      role: 'super_admin',
      expiresAt: DateTime.now().add(lifetime),
    );

http.Response jsonResponse(Map<String, dynamic> value, {int status = 200}) =>
    http.Response(jsonEncode(value), status, headers: {'content-type': 'application/json'});

void main() {
  group('ApiService', () {
    test('uses backend role ID instead of the display role label on login', () async {
      final store = MemorySessionStore();
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/auth/staff/login'));
        return jsonResponse({
          'success': true,
          'data': {
            'token': 'access-login',
            'refreshToken': 'refresh-login',
            'expiresInSeconds': 900,
            'staffDisplayName': 'مشرف الاختبار',
            'staffRoleId': 'content_manager',
            'staffRole': 'Content Manager',
          },
        });
      });

      final result = await ApiService(sessionStore: store, client: client)
          .login('editor', 'test-password');
      expect(result.role, 'content_manager');
      expect(store.value?.role, 'content_manager');
    });

    test('uses bearer token and unwraps API data envelope', () async {
      final store = MemorySessionStore(session());
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer access-1');
        expect(request.url.path, endsWith('/admin/dashboard/overview'));
        return jsonResponse({'success': true, 'data': {'students': 17}});
      });

      final result = await ApiService(sessionStore: store, client: client)
          .getDashboardOverview();
      expect(result['students'], 17);
    });

    test('supports PATCH, PUT, and DELETE requests', () async {
      final store = MemorySessionStore(session());
      final methods = <String>[];
      final client = MockClient((request) async {
        methods.add(request.method);
        return jsonResponse({'success': true, 'data': {'ok': true}});
      });
      final api = ApiService(sessionStore: store, client: client);

      await api.patch('/test/1', body: {'title': 'عنوان'});
      await api.put('/test/1', body: {'title': 'عنوان'});
      await api.delete('/test/1');
      expect(methods, ['PATCH', 'PUT', 'DELETE']);
    });

    test('coalesces simultaneous expired-session refreshes into one rotation', () async {
      final store = MemorySessionStore(session(lifetime: const Duration(seconds: -5)));
      var refreshCalls = 0;
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          if (!refreshStarted.isCompleted) { refreshStarted.complete(); }
          await releaseRefresh.future;
          return jsonResponse({
            'success': true,
            'data': {
              'token': 'access-rotated',
              'refreshToken': 'refresh-rotated',
              'expiresInSeconds': 900,
              'staffDisplayName': 'مشرف الاختبار',
              'staffRoleId': 'super_admin',
            },
          });
        }
        expect(request.headers['Authorization'], 'Bearer access-rotated');
        return jsonResponse({'success': true, 'data': {'ok': true}});
      });
      final api = ApiService(sessionStore: store, client: client);

      final first = api.get('/admin/security/eino-monitor');
      await refreshStarted.future;
      final second = api.get('/admin/security/eino-usage');
      releaseRefresh.complete();
      final results = await Future.wait([first, second]);

      expect(refreshCalls, 1);
      expect(results.every((result) => result['ok'] == true), isTrue);
      expect(store.value?.refreshToken, 'refresh-rotated');
    });

    test('extracts the backend nested error message', () async {
      final store = MemorySessionStore(session());
      final client = MockClient((request) async => jsonResponse({
            'success': false,
            'error': {'code': 'FORBIDDEN', 'message': 'ليست لديك صلاحية.'},
          }, status: 403));
      final api = ApiService(sessionStore: store, client: client);

      expect(
        () => api.getDashboardOverview(),
        throwsA(isA<ApiServiceException>().having(
          (error) => error.message,
          'message',
          'ليست لديك صلاحية.',
        )),
      );
    });

    test('rotates an expired session before making the requested call', () async {
      final store = MemorySessionStore(session(lifetime: const Duration(seconds: -5)));
      final methodsAndPaths = <String>[];
      final client = MockClient((request) async {
        methodsAndPaths.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/auth/refresh')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['refreshToken'], 'refresh-1');
          return jsonResponse({
            'success': true,
            'data': {
              'token': 'access-2',
              'refreshToken': 'refresh-2',
              'expiresInSeconds': 900,
              'staffDisplayName': 'مشرف الاختبار',
              'staffRoleId': 'super_admin',
              'staffRole': 'Super Admin',
            },
          });
        }
        expect(request.headers['Authorization'], 'Bearer access-2');
        return jsonResponse({'success': true, 'data': {'students': 20}});
      });

      final result = await ApiService(sessionStore: store, client: client)
          .getDashboardOverview();
      expect(result['students'], 20);
      expect(methodsAndPaths[0], contains('/auth/refresh'));
      expect(store.value?.accessToken, 'access-2');
      expect(store.value?.refreshToken, 'refresh-2');
      expect(store.value?.role, 'super_admin');
    });
  });
}
