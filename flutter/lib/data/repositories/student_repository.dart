import '../../core/network/api_client.dart';
import 'repository_parser.dart';
import '../models/student_profile.dart';

class StudentRepository {
  StudentRepository(this._client);
  final ApiClient _client;

  Future<StudentProfile> profile() async {
    final j = await _client.getJson('/api/v1/student/profile');
    final d = RepositoryParser.map(j);
    return StudentProfile.fromJson(d);
  }

  Future<Map<String, dynamic>> stats() async {
    final j = await _client.getJson('/api/v1/student/stats');
    return j['data'] is Map ? Map<String, dynamic>.from(j['data']) : const {};
  }

  Future<List<Map<String, dynamic>>> departments() async {
    final j = await _client.getJson('/api/v1/departments');
    return RepositoryParser.maps(j);
  }

  Future<List<Map<String, dynamic>>> semesters() async {
    final j = await _client.getJson('/api/v1/semesters');
    return RepositoryParser.maps(j);
  }

  Future<Map<String, dynamic>> register({
    required String studentNumber,
    required String email,
    required String password,
    required String semesterId,
    String? confirmPassword,
  }) async {
    final j = await _client.postJson('/api/v1/auth/register', body: {
      'studentNumber': studentNumber,
      'email': email.trim(),
      'password': password,
      'semesterId': semesterId,
      'confirmPassword': confirmPassword,
    });
    final d = j['data'];
    if (d is Map) return Map<String, dynamic>.from(d);
    throw const ApiException('Account creation failed.', code: 'ACCOUNT_CREATION_FAILED', kind: ApiErrorKind.response);
  }

}
