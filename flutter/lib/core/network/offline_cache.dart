import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage adapter for account-scoped offline data. Production uses the OS
/// secure-storage facility; tests can inject an in-memory implementation.
abstract interface class PersonalCacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
}

class _PlatformPersonalCacheStore implements PersonalCacheStore {
  const _PlatformPersonalCacheStore();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();
}

/// Persistent JSON cache. Public catalogue data is stored in SharedPreferences;
/// account-scoped learning state and conversation history use OS secure storage.
class OfflineCache {
  OfflineCache._();
  static final OfflineCache instance = OfflineCache._();

  PersonalCacheStore _personalStore = const _PlatformPersonalCacheStore();

  /// Test-only dependency seam; production code should never call this.
  void setPersonalStoreForTesting(PersonalCacheStore store) {
    _personalStore = store;
  }

  /// Metadata-aware cache read used for offline fallback and stale checks.
  Future<OfflineCacheEntry?> readEntry(String key, {Duration maxStale = const Duration(days: 7)}) async {
    final secureKey = _secureStorageKey(key);
    final raw = secureKey == null
        ? await _readPublicEntryRaw(key)
        : await _personalStore.read(secureKey);
    if (raw == null) return null;
    final entry = _decodeEntry(raw);
    if (entry == null) return null;
    final age = DateTime.now().toUtc().difference(entry.savedAt);
    if (age > maxStale) {
      if (secureKey != null) {
        await _personalStore.delete(secureKey);
      } else {
        await _removePublicEntry(key);
      }
      return null;
    }
    return OfflineCacheEntry(value: entry.value, savedAt: entry.savedAt);
  }

  static const _storageKey = 'trinex_offline_cache_v1';
  static const _personalStoragePrefix = 'trinex_offline_student_';
  static const _maxEntries = 160;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> write(String key, Map<String, dynamic> value) async {
    final savedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    final payload = jsonEncode({'savedAt': savedAt, 'value': value});
    final secureKey = _secureStorageKey(key);
    if (secureKey != null) {
      await _personalStore.write(secureKey, payload);
      await _prunePersonalScope(key.substring(0, key.indexOf('|')));
      return;
    }

    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    final Map<String, dynamic> cache = raw == null ? {} : _decodeMap(raw);
    cache[key] = {'savedAt': savedAt, 'value': value};
    _prune(cache);
    await prefs.setString(_storageKey, jsonEncode(cache));
  }

  Future<Map<String, dynamic>?> read(String key, {Duration maxStale = const Duration(days: 7)}) async {
    final entry = await readEntry(key, maxStale: maxStale);
    return entry?.value;
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_storageKey);
    final all = await _personalStore.readAll();
    await Future.wait(all.keys
        .where((key) => key.startsWith(_personalStoragePrefix))
        .map(_personalStore.delete));
  }

  /// Removes legacy unscoped personal entries from SharedPreferences. Current
  /// account-scoped entries remain available offline and are stored securely.
  Future<void> purgeSensitiveLegacyEntries() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final cache = _decodeMap(raw);
    const sensitivePaths = <String>[
      '/api/v1/student/stats',
      '/api/v1/student/profile',
      '/api/v1/chat/messages',
      '/api/v1/progress',
      '/api/v1/xp',
      '/api/v1/eino/chats',
      '/api/v1/eino/memory',
      '/api/v1/public/students/',
    ];
    final legacyPersonal = cache.entries.where((entry) =>
        entry.key.startsWith('student:') && sensitivePaths.any((path) => entry.key.contains(path))).toList();
    for (final entry in legacyPersonal) {
      final secureKey = _secureStorageKey(entry.key);
      if (secureKey != null) {
        await _personalStore.write(secureKey, jsonEncode(entry.value));
      }
      cache.remove(entry.key);
    }
    cache.removeWhere((key, _) =>
        !key.startsWith('student:') && sensitivePaths.any((path) => key.contains(path)));
    await prefs.setString(_storageKey, jsonEncode(cache));
  }

  Future<void> removePrefix(String prefix) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final cache = _decodeMap(raw);
      cache.removeWhere((key, _) => key.startsWith(prefix));
      await prefs.setString(_storageKey, jsonEncode(cache));
    }
    if (prefix.startsWith('student:') && prefix.endsWith('|')) {
      final scope = prefix.substring(0, prefix.length - 1);
      final securePrefix = '$_personalStoragePrefix${_encode(scope)}::';
      final all = await _personalStore.readAll();
      await Future.wait(all.keys
          .where((key) => key.startsWith(securePrefix))
          .map(_personalStore.delete));
    }
  }

  Future<void> removeMatching(String fragment) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final cache = _decodeMap(raw);
      cache.removeWhere((key, _) => key.contains(fragment));
      await prefs.setString(_storageKey, jsonEncode(cache));
    }
    final all = await _personalStore.readAll();
    final matching = all.keys.where((key) {
      if (!key.startsWith(_personalStoragePrefix)) return false;
      final separator = key.indexOf('::', _personalStoragePrefix.length);
      if (separator < 0) return false;
      try {
        final uri = utf8.decode(base64Url.decode(base64Url.normalize(key.substring(separator + 2))));
        return uri.contains(fragment);
      } catch (_) {
        return false;
      }
    });
    await Future.wait(matching.map(_personalStore.delete));
  }

  Future<String?> _readPublicEntryRaw(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    if (raw == null) return null;
    final entry = _decodeMap(raw)[key];
    return entry is Map ? jsonEncode(entry) : null;
  }

  Future<void> _removePublicEntry(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final cache = _decodeMap(raw)..remove(key);
    await prefs.setString(_storageKey, jsonEncode(cache));
  }

  OfflineCacheEntry? _decodeEntry(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final savedAt = int.tryParse('${decoded['savedAt']}');
      final value = decoded['value'];
      if (savedAt == null || value is! Map) return null;
      return OfflineCacheEntry(
        value: Map<String, dynamic>.from(value),
        savedAt: DateTime.fromMillisecondsSinceEpoch(savedAt, isUtc: true),
      );
    } catch (_) {
      return null;
    }
  }

  String? _secureStorageKey(String key) {
    if (!key.startsWith('student:')) return null;
    final separator = key.indexOf('|');
    if (separator <= 0 || separator == key.length - 1) return null;
    final scope = key.substring(0, separator);
    final resource = key.substring(separator + 1);
    return '$_personalStoragePrefix${_encode(scope)}::${_encode(resource)}';
  }

  String _encode(String value) => base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  Future<void> _prunePersonalScope(String scope) async {
    final prefix = '$_personalStoragePrefix${_encode(scope)}::';
    final all = await _personalStore.readAll();
    final entries = <MapEntry<String, int>>[];
    for (final item in all.entries) {
      if (!item.key.startsWith(prefix)) continue;
      final decoded = _decodeEntry(item.value);
      entries.add(MapEntry(item.key, decoded?.savedAt.millisecondsSinceEpoch ?? 0));
    }
    entries.sort((a, b) => a.value.compareTo(b.value));
    while (entries.length > _maxEntries) {
      await _personalStore.delete(entries.removeAt(0).key);
    }
  }

  Map<String, dynamic> _decodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  void _prune(Map<String, dynamic> cache) {
    if (cache.length <= _maxEntries) return;
    final entries = cache.entries.toList()
      ..sort((a, b) => _savedAt(a.value).compareTo(_savedAt(b.value)));
    while (entries.length > _maxEntries) {
      cache.remove(entries.removeAt(0).key);
    }
  }

  int _savedAt(dynamic value) => value is Map ? int.tryParse('${value['savedAt']}') ?? 0 : 0;
}

class OfflineCacheEntry {
  const OfflineCacheEntry({required this.value, required this.savedAt});

  final Map<String, dynamic> value;
  final DateTime savedAt;

  Duration get age => DateTime.now().toUtc().difference(savedAt);
}
