import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import 'repository_parser.dart';
import '../models/material_progress.dart';

class ProgressRepository {
  ProgressRepository(this._client);
  final ApiClient _client;

  Future<ProgressSnapshot> getProgress() async {
    final json = await _client.getJson('/api/v1/progress', cacheTtl: const Duration(minutes: 5));
    final items = RepositoryParser.maps(json)
        .map(MaterialProgress.fromJson)
        .toList(growable: false);
    final meta = json['meta'];
    final summary = meta is Map ? Map<String, dynamic>.from(meta['summary'] is Map ? meta['summary'] : const {}) : const <String, dynamic>{};
    return ProgressSnapshot(items: items, summary: summary);
  }

  String _queueKey(String scope) => 'trinex_pending_progress_v1_$scope';

  Future<Map<String, dynamic>> _readQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey(await _client.cacheScope));
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) { return <String, dynamic>{}; }
  }

  Future<void> _writeQueue(Map<String, dynamic> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _queueKey(await _client.cacheScope);
    if (queue.isEmpty) { await prefs.remove(key); return; }
    await prefs.setString(key, jsonEncode(queue));
  }

  /// Persist the latest page locally on every page change; no network request.
  Future<void> savePending({required String materialId, required int progressPercent, required int pageNumber, required int pageCount}) async {
    final queue = await _readQueue();
    queue[materialId] = <String, dynamic>{
      'progressPercent': progressPercent.clamp(0, 100),
      'pageNumber': pageNumber < 0 ? 0 : pageNumber,
      'pageCount': pageCount < 0 ? 0 : pageCount,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _writeQueue(queue);
  }

  Future<void> syncPending({String? exceptMaterialId}) async {
    final queue = await _readQueue();
    if (queue.isEmpty) return;
    for (final entry in queue.entries.toList()) {
      if (entry.key == exceptMaterialId || entry.value is! Map) continue;
      final item = Map<String, dynamic>.from(entry.value as Map);
      try {
        await _client.postJson('/api/v1/materials/${Uri.encodeComponent(entry.key)}/progress', body: {
          'eventType': (int.tryParse('${item['progressPercent']}') ?? 0) >= 100 ? 'complete' : 'progress',
          'progressPercent': item['progressPercent'] ?? 0,
          'pageNumber': item['pageNumber'] ?? 0,
          'pageCount': item['pageCount'] ?? 0,
        });
        queue.remove(entry.key);
        await _writeQueue(queue);
      } catch (_) {
        // Keep the item until a future successful network attempt.
      }
    }
  }

  Future<ProgressUpdate> record({required String materialId, required String eventType, int progressPercent = 0, int pageNumber = 0, int pageCount = 0}) async {
    try { await syncPending(exceptMaterialId: materialId); } catch (_) {}
    if (eventType != 'open') {
      try { await savePending(materialId: materialId, progressPercent: progressPercent, pageNumber: pageNumber, pageCount: pageCount); } catch (_) {}
    }
    try {
      final json = await _client.postJson('/api/v1/materials/${Uri.encodeComponent(materialId)}/progress', body: {
        'eventType': eventType,
        'progressPercent': progressPercent,
        'pageNumber': pageNumber,
        'pageCount': pageCount,
      });
      final update = ProgressUpdate.fromJson(RepositoryParser.map(json));
      if (update.xpAwarded > 0) {
        await _client.invalidateCacheForPath('/api/v1/xp');
        await _client.invalidateCacheForPath('/api/v1/student/stats');
      }
      await _client.invalidateCacheForPath('/api/v1/badges');
      await _client.invalidateCacheForPath('/api/v1/progress');
      try {
        if (eventType != 'open') {
          final queue = await _readQueue();
          queue.remove(materialId);
          await _writeQueue(queue);
        }
      } catch (_) {}
      return update;
    } catch (_) {
      // A failed request leaves the latest progress safely queued on-device.
      rethrow;
    }
  }
}

class ProgressSnapshot {
  const ProgressSnapshot({required this.items, required this.summary});
  final List<MaterialProgress> items;
  final Map<String, dynamic> summary;
}

class ProgressUpdate {
  const ProgressUpdate({required this.percent, required this.completed, required this.activeSeconds, required this.accepted, this.pageNumber = 0, this.pageCount = 0, this.xpAwarded = 0});
  final int percent;
  final bool completed;
  final int activeSeconds;
  final bool accepted;
  final int pageNumber;
  final int pageCount;
  final int xpAwarded;

  factory ProgressUpdate.fromJson(Map<String, dynamic> json) => ProgressUpdate(
    percent: RepositoryParser.integer(json['progressPercent']),
    completed: json['completed'] == true || json['completed'] == 1,
    activeSeconds: RepositoryParser.integer(json['activeSeconds']),
    accepted: json['accepted'] != false,
    pageNumber: RepositoryParser.integer(json['pageNumber']),
    pageCount: RepositoryParser.integer(json['pageCount']),
    xpAwarded: RepositoryParser.integer(json['xpAwarded']),
  );
}
