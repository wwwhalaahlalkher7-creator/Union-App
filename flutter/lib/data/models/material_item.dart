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
    this.mimeType,
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
  final String? mimeType;
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
      // Students only receive the application's authenticated file endpoint.
      // Raw Drive URLs are intentionally not exposed to the app.
      url: (json['file_url'] ?? json['fileUrl'] ?? json['url'])?.toString(),
      mimeType: (json['mime_type'] ?? json['mimeType'] ?? 'application/pdf')?.toString(),
      size: int.tryParse((json['size_bytes'] ?? json['size'] ?? '').toString()),
      pinned: json['pinned'] == true || json['pinned'] == 1,
    );
  }
}
