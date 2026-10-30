import '../../core/network/api_client.dart';
import '../models/material_item.dart';
import 'repository_parser.dart';

class MaterialsRepository {
  MaterialsRepository(this._client);
  final ApiClient _client;

  Future<List<Map<String, dynamic>>> semesters() async {
    final json = await _client.getJson('/api/v1/semesters');
    return RepositoryParser.maps(json);
  }

  Future<List<Map<String, dynamic>>> subjects({required String semesterId}) async {
    final json = await _client.getJson(
      '/api/v1/subjects',
      query: {'semesterId': semesterId},
    );
    return RepositoryParser.maps(json);
  }

  Future<MaterialItem> getById(String materialId) async {
    final json = await _client.getJson(
      '/api/v1/materials/${Uri.encodeComponent(materialId)}',
      forceRefresh: true,
    );
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    return MaterialItem.fromJson(data);
  }

  Future<List<MaterialItem>> exams({String? semesterId, String? subjectId}) async {
    final query = <String, String>{'limit': '500'};
    if (semesterId != null && semesterId.isNotEmpty) query['semesterId'] = semesterId;
    if (subjectId != null && subjectId.isNotEmpty) query['subjectId'] = subjectId;
    final json = await _client.getJson('/api/v1/exams', query: query, forceRefresh: true);
    return RepositoryParser.maps(json).map(MaterialItem.fromJson).toList(growable: false);
  }

  Future<List<MaterialItem>> list({String? semesterId, String? subjectId}) async {
    final query = <String, String>{'limit': '100'};
    if (semesterId != null && semesterId.isNotEmpty) {
      query['semesterId'] = semesterId;
    }
    if (subjectId != null && subjectId.isNotEmpty) {
      query['subjectId'] = subjectId;
    }

    final json = await _client.getJson('/api/v1/materials', query: query);
    return RepositoryParser.maps(json)
        .map(MaterialItem.fromJson)
        .toList(growable: false);
  }
}
