import '../../core/network/api_client.dart';
import 'repository_parser.dart';
import '../models/material_progress.dart';

class ProgressRepository {
  ProgressRepository(this._client);
  final ApiClient _client;

  Future<ProgressSnapshot> getProgress() async {
    final json = await _client.getJson('/api/v1/progress');
    final items = RepositoryParser.maps(json)
        .map(MaterialProgress.fromJson)
        .toList(growable: false);
    final meta = json['meta'];
    final summary = meta is Map ? Map<String, dynamic>.from(meta['summary'] is Map ? meta['summary'] : const {}) : const <String, dynamic>{};
    return ProgressSnapshot(items: items, summary: summary);
  }

  Future<ProgressUpdate> record({required String materialId, required String eventType, int progressPercent = 0, int pageNumber = 0, int pageCount = 0}) async {
    final json = await _client.postJson('/api/v1/materials/$materialId/progress', body: {
      'eventType': eventType,
      'progressPercent': progressPercent,
      'pageNumber': pageNumber,
      'pageCount': pageCount,
    });
    return ProgressUpdate.fromJson(RepositoryParser.map(json));
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
