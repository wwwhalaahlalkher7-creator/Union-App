import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small persistent JSON cache used only for read-only, non-secret app data.
/// Authentication tokens and Eino conversations/memory are deliberately excluded.
class OfflineCache {
  OfflineCache._();
  static final OfflineCache instance = OfflineCache._();

  static const _storageKey = 'trinex_offline_cache_v1';
  static const _maxEntries = 80;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> write(String key, Map<String, dynamic> value) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    final Map<String, dynamic> cache = raw == null ? {} : _decodeMap(raw);
    cache[key] = {
      'savedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
      'value': value,
    };
    _prune(cache);
    await prefs.setString(_storageKey, jsonEncode(cache));
  }

  Future<Map<String, dynamic>?> read(String key, {Duration maxStale = const Duration(days: 7)}) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    if (raw == null) return null;
    final cache = _decodeMap(raw);
    final entry = cache[key];
    if (entry is! Map) return null;
    final savedAt = int.tryParse('${entry['savedAt']}');
    final value = entry['value'];
    if (savedAt == null || value is! Map) return null;
    final age = DateTime.now().toUtc().difference(DateTime.fromMillisecondsSinceEpoch(savedAt, isUtc: true));
    if (age > maxStale) {
      cache.remove(key);
      await prefs.setString(_storageKey, jsonEncode(cache));
      return null;
    }
    return Map<String, dynamic>.from(value);
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_storageKey);
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
