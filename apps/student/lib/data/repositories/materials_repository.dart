import '../../core/network/api_client.dart';
import '../models/material_item.dart';

class MaterialsRepository {
  MaterialsRepository(this._client);
  final ApiClient _client;

  Future<List<Map<String, dynamic>>> semesters() async {
    final json = await _client.getJson('/api/v1/semesters');
    final raw = json['data'];
    return raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
  }

  Future<List<Map<String, dynamic>>> subjects({required String semesterId}) async {
    final json = await _client.getJson('/api/v1/subjects', query: {'semesterId': semesterId});
    final raw = json['data'];
    return raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
  }

  Future<List<MaterialItem>> list({String? semesterId, String? subjectId}) async {
    final query = <String, String>{'limit': '100'};
    if (semesterId != null && semesterId.isNotEmpty) query['semesterId'] = semesterId;
    if (subjectId != null && subjectId.isNotEmpty) query['subjectId'] = subjectId;
    final json = await _client.getJson('/api/v1/materials', query: query);
    final raw = json['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => MaterialItem.fromJson(Map<String, dynamic>.from(item))).toList();
  }
}
