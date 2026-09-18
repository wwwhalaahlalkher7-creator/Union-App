class CommentItem {
  const CommentItem({required this.id, required this.studentName, required this.body, required this.createdAt, this.reactionCount = 0});
  final String id;
  final String studentName;
  final String body;
  final String createdAt;
  final int reactionCount;
  factory CommentItem.fromJson(Map<String,dynamic> j)=>CommentItem(id:'${j['id']??''}',studentName:'${j['full_name']??'طالب'}',body:'${j['body']??''}',createdAt:'${j['created_at']??''}',reactionCount:int.tryParse('${j['reaction_count']??0}')??0);
}
