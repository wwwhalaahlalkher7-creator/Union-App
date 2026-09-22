import '../../core/network/api_client.dart';
import '../models/student_profile.dart';

class StudentRepository {
  StudentRepository(this._client);
  final ApiClient _client;

  Future<StudentProfile> profile() async {
    final j = await _client.getJson('/api/v1/student/profile');
    final d = j['data'];
    return StudentProfile.fromJson(d is Map ? Map<String, dynamic>.from(d) : const {});
  }

  Future<Map<String, dynamic>> stats() async {
    final j = await _client.getJson('/api/v1/student/stats');
    return j['data'] is Map ? Map<String, dynamic>.from(j['data']) : const {};
  }

  Future<List<Map<String, dynamic>>> departments() async {
    final j = await _client.getJson('/api/v1/departments');
    final d = j['data'];
    return d is List ? d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
  }

  Future<List<Map<String, dynamic>>> semesters() async {
    final j = await _client.getJson('/api/v1/semesters');
    final d = j['data'];
    return d is List ? d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
  }

  Future<Map<String, dynamic>> register({
    required String studentNumber,
    required String email,
    required String password,
    String? confirmPassword,
  }) async {
    final j = await _client.postJson('/api/v1/auth/register', body: {
      'studentNumber': studentNumber,
      'email': email.trim(),
      'password': password,
      'confirmPassword': ?confirmPassword,
    });
    final d = j['data'];
    if (d is Map) return Map<String, dynamic>.from(d);
    throw const ApiException('فشل إنشاء الحساب. يرجى التحقق من البيانات والمحاولة مجددًا.');
  }

}
