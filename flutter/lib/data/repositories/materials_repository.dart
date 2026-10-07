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
