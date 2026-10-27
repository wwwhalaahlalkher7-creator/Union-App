class CommentItem {
  const CommentItem({
    required this.id,
    required this.studentName,
    required this.body,
    required this.createdAt,
    this.reactionCount = 0,
    this.liked = false,
  });

  final String id;
  final String studentName;
  final String body;
  final String createdAt;
  final int reactionCount;
  final bool liked;

  factory CommentItem.fromJson(Map<String, dynamic> j) => CommentItem(
        id: '${j['id'] ?? ''}',
        studentName: '${j['full_name'] ?? 'طالب'}',
        body: '${j['body'] ?? ''}',
        createdAt: '${j['created_at'] ?? ''}',
        reactionCount: int.tryParse('${j['reaction_count'] ?? 0}') ?? 0,
        liked: '${j['my_reaction'] ?? ''}'.toLowerCase() == 'like',
      );

  CommentItem copyWith({int? reactionCount, bool? liked}) => CommentItem(
        id: id,
        studentName: studentName,
        body: body,
        createdAt: createdAt,
        reactionCount: reactionCount ?? this.reactionCount,
        liked: liked ?? this.liked,
      );
}
