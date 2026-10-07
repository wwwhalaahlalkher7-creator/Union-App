import '../../core/network/api_client.dart';
import '../models/schedule_item.dart';
import 'repository_parser.dart';

class ScheduleData {
  const ScheduleData({
    required this.semester,
    required this.department,
    required this.items,
    required this.days,
  });

  final Map<String, dynamic>? semester;
  final Map<String, dynamic>? department;
  final List<ScheduleItem> items;
  final List<int> days;
}

class ScheduleRepository {
  ScheduleRepository(this._client);

  final ApiClient _client;

  Future<ScheduleData> getSchedule({String? semesterId}) async {
    final query = <String, String>{};
    if (semesterId != null && semesterId.isNotEmpty) {
      query['semesterId'] = semesterId;
    }

    final json = await _client.getJson('/api/v1/schedule', query: query);
    final data = RepositoryParser.map(json);
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => ScheduleItem.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : const <ScheduleItem>[];
    items.sort((a, b) {
      final day = a.dayOfWeek.compareTo(b.dayOfWeek);
      return day != 0 ? day : a.startTime.compareTo(b.startTime);
    });

    final days = (data['days'] is List ? data['days'] as List : const <dynamic>[])
        .map(RepositoryParser.integer)
        .toList(growable: false);

    return ScheduleData(
      semester: data['semester'] is Map
          ? Map<String, dynamic>.from(data['semester'] as Map)
          : null,
      department: data['department'] is Map
          ? Map<String, dynamic>.from(data['department'] as Map)
          : null,
      items: items,
      days: days,
    );
  }

  Future<List<Map<String, dynamic>>> semesters() async {
    final json = await _client.getJson('/api/v1/semesters');
    return RepositoryParser.maps(json);
  }
}
