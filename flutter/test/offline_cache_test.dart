import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leo_association/core/network/offline_cache.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
}
