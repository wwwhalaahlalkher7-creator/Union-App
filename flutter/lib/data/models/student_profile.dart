class StudentProfile {
  const StudentProfile({required this.id, required this.number, required this.name, required this.departmentId, this.departmentName, this.semesterId});
  final String id, number, name, departmentId; final String? departmentName, semesterId;
  factory StudentProfile.fromJson(Map<String,dynamic> j) => StudentProfile(
    id: '${j['studentId'] ?? j['id'] ?? ''}', number: '${j['studentNumber'] ?? j['student_number'] ?? ''}',
    name: '${j['fullName'] ?? j['full_name'] ?? ''}', departmentId: '${j['departmentId'] ?? j['department_id'] ?? ''}',
    departmentName: j['departmentName']?.toString(), semesterId: j['currentSemesterId']?.toString() ?? j['current_semester_id']?.toString());
}
