import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leo_association/core/network/api_client.dart';
import 'package:leo_association/core/network/offline_cache.dart';

class _MemoryPersonalCacheStore implements PersonalCacheStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async => Map<String, String>.from(values);
}

void main() {
  late _MemoryPersonalCacheStore personalStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    personalStore = _MemoryPersonalCacheStore();
    OfflineCache.instance.setPersonalStoreForTesting(personalStore);
    await OfflineCache.instance.clear();
    ApiClient.resetCachesForTesting();
  });

  test('coalesces concurrent identical GET requests into one HTTP call', () async {
    var calls = 0;
    final gate = Completer<void>();
    final requestEntered = Completer<void>();
    final client = MockClient((request) async {
      calls++;
      if (!requestEntered.isCompleted) {
        requestEntered.complete();
      }
      await gate.future;
      return http.Response(
        jsonEncode({'success': true, 'data': {'value': 7}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(baseUrl: 'https://example.test', client: client);
    addTearDown(api.dispose);

    final first = api.getJson(
      '/api/v1/public/news',
      query: const {'case': 'dedupe'},
      cacheTtl: const Duration(minutes: 5),
      forceRefresh: true,
    );
    await requestEntered.future;
    final second = api.getJson(
      '/api/v1/public/news',
      query: const {'case': 'dedupe'},
      cacheTtl: const Duration(minutes: 5),
      forceRefresh: true,
    );

    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(results[0]['data']['value'], 7);
    expect(results[1]['data']['value'], 7);
    expect(calls, 1);
    expect(ApiClient.cacheMetrics.coalescedGets, 1);
    expect(ApiClient.cacheMetrics.networkGets, 1);
  });

  test('does not persist personal progress payloads to the offline cache', () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({'success': true, 'data': {'progress': 42}}),
          200,
          headers: {'content-type': 'application/json'},
        ));
    final api = ApiClient(baseUrl: 'https://example.test', client: client);
    addTearDown(api.dispose);

    await api.getJson('/api/v1/progress');

    const publicKey = 'public|https://example.test/api/v1/progress';
    expect(await OfflineCache.instance.read(publicKey), isNull);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('trinex_offline_cache_v1') ?? '';
    expect(raw, isNot(contains('/api/v1/progress')));
    expect(personalStore.values, isEmpty);
  });

}

