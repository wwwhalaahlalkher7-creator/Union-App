import 'dart:convert';

class ContentItem {
  const ContentItem({
    required this.id,
    required this.title,
    this.summary,
    this.body,
    this.createdAt,
    this.updatedAt,
    this.imageUrl,
    this.category,
    this.publisher,
    this.eventAt,
    this.endAt,
    this.location,
    this.commentCount = 0,
    this.likeCount = 0,
    this.myReaction,
    this.images = const <String>[],
    this.highlightsTitle,
    this.highlights = const <String>[],
    this.badge,
  });

  final String id;
  final String title;
  final String? summary;
  final String? body;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? imageUrl;
  final String? category;
  final String? publisher;
  final DateTime? eventAt;
  final DateTime? endAt;
  final String? location;
  final int commentCount;
  final int likeCount;
  final String? myReaction;
  final List<String> images;
  final String? highlightsTitle;
  final List<String> highlights;
  final String? badge;

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'] is Map
        ? Map<String, dynamic>.from(json['fields'] as Map)
        : json;

    DateTime? parseDate(dynamic value, {bool inclusiveEndDate = false}) {
      if (value == null) return null;
      final raw = value.toString().trim();
      if (raw.isEmpty) return null;
      // Values without an explicit zone are entered as Sudan wall time.
      // Pin them to UTC+02:00 so device timezone settings do not change the
      // represented instant. DateTime.parse keeps the instant when converting.
      final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(raw);
      final dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw);
      final normalized = hasZone
          ? raw
          : dateOnly
              ? '${raw}T00:00:00+02:00'
              : raw.contains('T')
                  ? '$raw+02:00'
                  : RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:').hasMatch(raw)
                      ? '${raw.replaceFirst(' ', 'T')}+02:00'
                      : '${raw}T00:00:00+02:00';
      final parsed = DateTime.tryParse(normalized);
      if (parsed == null) return null;
      final midnightValue = dateOnly || RegExp(
        r'(?:T| )00:00(?::00(?:\.0+)?)?(?:Z|[+-]\d{2}:?\d{2})?$',
        caseSensitive: false,
      ).hasMatch(raw);
      if (inclusiveEndDate && midnightValue) {
        return DateTime.fromMillisecondsSinceEpoch(
          parsed.millisecondsSinceEpoch + const Duration(days: 1).inMilliseconds - 1,
        );
      }
      return parsed;
    }

    return ContentItem(
      id: (json['id'] ?? json['ID'] ?? fields['id'] ?? fields['ID'] ?? '')
          .toString(),
      title: (fields['title'] ??
              fields['Title'] ??
              fields['name'] ??
              fields['Name'] ??
              '')
          .toString(),
      summary: (fields['summary'] ??
              fields['Summary'] ??
              fields['description'] ??
              fields['Description'])
          ?.toString(),
      body: (fields['body'] ?? fields['Body'] ?? fields['content'] ?? fields['Content'] ?? fields['description'] ?? fields['Description'] ?? fields['intro'] ?? fields['Intro'])
          ?.toString(),
      createdAt: parseDate(
        fields['createdAt'] ??
            fields['created_at'] ??
            fields['CreatedAt'] ??
            fields['Date'],
      ),
      updatedAt: parseDate(
        fields['updatedAt'] ?? fields['updated_at'] ?? fields['UpdatedAt'],
      ),
      imageUrl: (fields['imageUrl'] ?? fields['image_url'])?.toString(),
      category: fields['category']?.toString(),
      publisher: fields['publisher']?.toString(),
      eventAt: parseDate(fields['eventAt'] ?? fields['event_at']),
      endAt: parseDate(fields['endAt'] ?? fields['end_at'], inclusiveEndDate: true),
      location: fields['location']?.toString(),
      commentCount: _toInt(fields['commentCount'] ?? fields['comment_count']),
      likeCount: _toInt(fields['likeCount'] ?? fields['like_count']),
      myReaction: (fields['myReaction'] ?? fields['my_reaction'])?.toString(),
      images: _toImages(fields['images'] ?? fields['images_json']),
      highlightsTitle: (fields['highlightsTitle'] ?? fields['highlights_title'])?.toString(),
      highlights: _toHighlights(fields['highlights']),
      badge: (fields['badge'] ?? fields['Badge'])?.toString(),
    );
  }
}

List<String> _toImages(dynamic value) {
  if (value is List) return value.map((v) => v is Map ? '${v['url'] ?? ''}' : '$v').where((v) => v.trim().isNotEmpty).toList();
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded.map((v) => v is Map ? '${v['url'] ?? ''}' : '$v').where((v) => v.trim().isNotEmpty).toList();
    } catch (_) {}
  }
  return const <String>[];
}

int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _toHighlights(dynamic value) {
  if (value is List) return value.map((v) => v is Map ? '${v['text'] ?? v['title'] ?? v['value'] ?? ''}' : '$v').where((v) => v.trim().isNotEmpty).toList();
  if (value is String && value.trim().isNotEmpty) {
    try { final decoded = jsonDecode(value); return _toHighlights(decoded); } catch (_) {}
  }
  return const <String>[];
}
