class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.departmentId,
    required this.semesterId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    this.subjectId,
    this.subjectCode,
    this.subjectNameEn,
    this.room,
    this.lecturer,
  });

  final String id;
  final String departmentId;
  final String semesterId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String subjectName;
  final String? subjectId;
  final String? subjectCode;
  final String? subjectNameEn;
  final String? room;
  final String? lecturer;

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: (json['id'] ?? '').toString(),
      departmentId: (json['departmentId'] ?? json['department_id'] ?? '').toString(),
      semesterId: (json['semesterId'] ?? json['semester_id'] ?? '').toString(),
      dayOfWeek: int.tryParse((json['dayOfWeek'] ?? json['day_of_week'] ?? '').toString()) ?? 0,
      startTime: (json['startTime'] ?? json['start_time'] ?? '').toString(),
      endTime: (json['endTime'] ?? json['end_time'] ?? '').toString(),
      subjectName: (json['subjectName'] ?? json['subject_name'] ?? '').toString(),
      subjectId: json['subjectId']?.toString() ?? json['subject_id']?.toString(),
      subjectCode: json['subjectCode']?.toString() ?? json['subject_code']?.toString(),
      subjectNameEn: json['subjectNameEn']?.toString() ?? json['subject_name_en']?.toString(),
      room: json['room']?.toString(),
      lecturer: json['lecturer']?.toString() ?? json['instructor']?.toString(),
    );
  }
}
