class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.number,
    required this.name,
    required this.departmentId,
    this.email,
    this.departmentName,
    this.semesterId,
    this.semesterName,
    this.isModerator = false,
  });

  final String id;
  final String number;
  final String name;
  final String departmentId;
  final String? email;
  final String? departmentName;
  final String? semesterId;
  final String? semesterName;
  final bool isModerator;

  String get studentNumber => number;

  factory StudentProfile.fromJson(Map<String, dynamic> j) => StudentProfile(
        id: '${j['studentId'] ?? j['id'] ?? ''}',
        number: '${j['studentNumber'] ?? j['student_number'] ?? ''}',
        name: '${j['fullName'] ?? j['full_name'] ?? ''}',
        departmentId: '${j['departmentId'] ?? j['department_id'] ?? ''}',
        email: j['email']?.toString(),
        departmentName: j['departmentName']?.toString(),
        semesterId: j['currentSemesterId']?.toString() ??
            j['current_semester_id']?.toString() ??
            j['semesterId']?.toString(),
        semesterName: j['semesterName']?.toString() ??
            j['currentSemesterName']?.toString(),
        isModerator: j['isModerator'] == true || j['isModerator'] == 1 || j['is_moderator'] == 1,
      );
}
