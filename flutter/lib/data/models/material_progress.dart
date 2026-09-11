class MaterialProgress {
  const MaterialProgress({
    required this.materialId,
    required this.percent,
    required this.completed,
    required this.activeSeconds,
    this.materialTitle,
    this.subjectName,
    this.lastOpenedAt,
  });

  final String materialId;
  final int percent;
  final bool completed;
  final int activeSeconds;
  final String? materialTitle;
  final String? subjectName;
  final String? lastOpenedAt;

  factory MaterialProgress.fromJson(Map<String, dynamic> json) => MaterialProgress(
    materialId: (json['material_id'] ?? json['materialId'] ?? '').toString(),
    percent: int.tryParse((json['progress_percent'] ?? json['progressPercent'] ?? 0).toString()) ?? 0,
    completed: json['completed_at'] != null || json['completed'] == true || json['completed'] == 1,
    activeSeconds: int.tryParse((json['active_seconds'] ?? json['activeSeconds'] ?? 0).toString()) ?? 0,
    materialTitle: (json['material_title'] ?? json['materialTitle'])?.toString(),
    subjectName: (json['subject_name'] ?? json['subjectName'])?.toString(),
    lastOpenedAt: (json['last_opened_at'] ?? json['lastOpenedAt'])?.toString(),
  );
}
