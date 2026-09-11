class MaterialItem {
  const MaterialItem({
    required this.id,
    required this.name,
    this.subjectId,
    this.subject,
    this.subjectCode,
    this.department,
    this.semesterId,
    this.semester,
    this.url,
    this.size,
    this.pinned = false,
  });

  final String id;
  final String name;
  final String? subjectId;
  final String? subject;
  final String? subjectCode;
  final String? department;
  final String? semesterId;
  final int? semester;
  final String? url;
  final int? size;
  final bool pinned;

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    final semesterValue = json['semester'] ?? json['semesterNumber'] ?? json['semester_name'] ?? json['semesterName'];
    return MaterialItem(
      id: (json['id'] ?? '').toString(),
      name: (json['title'] ?? json['name'] ?? json['materialName'] ?? '').toString(),
      subjectId: json['subject_id']?.toString(),
      subject: (json['subject_name'] ?? json['subject'] ?? json['materialName'])?.toString(),
      subjectCode: json['subject_code']?.toString(),
      department: (json['department'] ?? json['sectionName'] ?? json['section'])?.toString(),
      semesterId: json['semester_id']?.toString(),
      semester: int.tryParse(semesterValue?.toString() ?? ''),
      url: (json['drive_web_view_url'] ?? json['drive_url'] ?? json['url'] ?? json['downloadLink'] ?? json['webViewLink'] ?? json['link'])?.toString(),
      size: int.tryParse((json['size_bytes'] ?? json['size'] ?? '').toString()),
      pinned: json['pinned'] == true || json['pinned'] == 1,
    );
  }
}
