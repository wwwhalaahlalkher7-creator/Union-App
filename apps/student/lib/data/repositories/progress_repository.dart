import '../../core/network/api_client.dart';
import '../models/material_progress.dart';

class ProgressRepository {
  ProgressRepository(this._client);
  final ApiClient _client;

  Future<ProgressSnapshot> getProgress() async {
    final json = await _client.getJson('/api/v1/progress');
    final raw = json['data'];
    final items = raw is List
        ? raw.whereType<Map>().map((e) => MaterialProgress.fromJson(Map<String, dynamic>.from(e))).toList()
        : const <MaterialProgress>[];
    final meta = json['meta'];
    final summary = meta is Map ? Map<String, dynamic>.from(meta['summary'] is Map ? meta['summary'] : const {}) : const <String, dynamic>{};
    return ProgressSnapshot(items: items, summary: summary);
  }

  Future<ProgressUpdate> record({required String materialId, required String eventType, int progressPercent = 0}) async {
    final json = await _client.postJson('/api/v1/materials/$materialId/progress', body: {
      'eventType': eventType,
      'progressPercent': progressPercent,
    });
    final data = json['data'];
    return ProgressUpdate.fromJson(data is Map ? Map<String, dynamic>.from(data) : const {});
  }
}

class ProgressSnapshot {
  const ProgressSnapshot({required this.items, required this.summary});
  final List<MaterialProgress> items;
  final Map<String, dynamic> summary;
}

class ProgressUpdate {
  const ProgressUpdate({required this.percent, required this.completed, required this.activeSeconds, required this.accepted});
  final int percent;
  final bool completed;
  final int activeSeconds;
  final bool accepted;

  factory ProgressUpdate.fromJson(Map<String, dynamic> json) => ProgressUpdate(
    percent: int.tryParse((json['progressPercent'] ?? 0).toString()) ?? 0,
    completed: json['completed'] == true || json['completed'] == 1,
    activeSeconds: int.tryParse((json['activeSeconds'] ?? 0).toString()) ?? 0,
    accepted: json['accepted'] != false,
  );
}
