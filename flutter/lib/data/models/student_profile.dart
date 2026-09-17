class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.number,
    required this.name,
    required this.departmentId,
    this.departmentName,
    this.semesterId,
    this.semesterName,
  });

  final String id;
  final String number;
  final String name;
  final String departmentId;
  final String? departmentName;
  final String? semesterId;
  final String? semesterName;

  String get studentNumber => number;

  factory StudentProfile.fromJson(Map<String, dynamic> j) => StudentProfile(
        id: '${j['studentId'] ?? j['id'] ?? ''}',
        number: '${j['studentNumber'] ?? j['student_number'] ?? ''}',
        name: '${j['fullName'] ?? j['full_name'] ?? ''}',
        departmentId: '${j['departmentId'] ?? j['department_id'] ?? ''}',
        departmentName: j['departmentName']?.toString(),
        semesterId: j['currentSemesterId']?.toString() ??
            j['current_semester_id']?.toString() ??
            j['semesterId']?.toString(),
        semesterName: j['semesterName']?.toString() ??
            j['currentSemesterName']?.toString(),
      );
}
