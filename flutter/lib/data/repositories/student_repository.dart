import '../../core/network/api_client.dart';
import '../models/student_profile.dart';
class StudentRepository {
  StudentRepository(this._client); final ApiClient _client;
  Future<StudentProfile> profile() async { final j=await _client.getJson('/api/v1/student/profile'); final d=j['data']; return StudentProfile.fromJson(d is Map ? Map<String,dynamic>.from(d) : const {}); }
  Future<Map<String,dynamic>> stats() async { final j=await _client.getJson('/api/v1/student/stats'); return j['data'] is Map ? Map<String,dynamic>.from(j['data']) : const {}; }
}
