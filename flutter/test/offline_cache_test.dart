import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leo_association/core/network/offline_cache.dart';

class _MemoryPersonalCacheStore implements PersonalCacheStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async { values[key] = value; }
  @override
  Future<void> delete(String key) async { values.remove(key); }
  @override
  Future<Map<String, String>> readAll() async => Map<String, String>.from(values);
}

void main() {
  late _MemoryPersonalCacheStore personalStore;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    personalStore = _MemoryPersonalCacheStore();
    OfflineCache.instance.setPersonalStoreForTesting(personalStore);
  });

  test('persists and reads JSON cache entries', () async {
    final cache = OfflineCache.instance;
    await cache.write('k', {'success': true, 'data': {'items': [1, 2]}});
    final value = await cache.read('k');
    expect(value?['success'], true);
    expect(jsonEncode(value?['data']), '{"items":[1,2]}');
  });

  test('missing cache returns null', () async {
    expect(await OfflineCache.instance.read('missing'), isNull);
  });

  test('personal cache is stored in secure account-scoped storage', () async {
    final cache = OfflineCache.instance;
    await cache.write('student:100|/api/v1/eino/chats/abc/messages', {'data': 'private chat'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('trinex_offline_cache_v1'), isNull);
    expect((await cache.read('student:100|/api/v1/eino/chats/abc/messages'))?['data'], 'private chat');
    expect((await cache.read('student:200|/api/v1/eino/chats/abc/messages')), isNull);
    await cache.removePrefix('student:100|');
    expect(await cache.read('student:100|/api/v1/eino/chats/abc/messages'), isNull);
  });

  test('removePrefix clears only entries belonging to one account scope', () async {
    final cache = OfflineCache.instance;
    await cache.write('student:100|/api/v1/progress', {'data': 'private'});
    await cache.write('student:200|/api/v1/progress', {'data': 'other'});
    await cache.write('public|/api/v1/public/news', {'data': 'public'});

    await cache.removePrefix('student:100|');

    expect(await cache.read('student:100|/api/v1/progress'), isNull);
    expect((await cache.read('student:200|/api/v1/progress'))?['data'], 'other');
    expect((await cache.read('public|/api/v1/public/news'))?['data'], 'public');
  });
}
