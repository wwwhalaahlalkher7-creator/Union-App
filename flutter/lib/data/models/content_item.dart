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
    this.location,
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
  final String? location;

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'] is Map
        ? Map<String, dynamic>.from(json['fields'] as Map)
        : json;

    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());

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
      body: (fields['body'] ?? fields['Body'] ?? fields['content'] ?? fields['Content'])
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
      location: fields['location']?.toString(),
    );
  }
}
