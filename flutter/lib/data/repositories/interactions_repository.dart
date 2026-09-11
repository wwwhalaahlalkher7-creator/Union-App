import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../models/comment_item.dart';

class InteractionsRepository {
  InteractionsRepository(this._client);
  final ApiClient _client;
  Future<List<CommentItem>> comments(String type,String id,{int offset=0}) async { final j=await _client.getJson('/content/$type/$id/comments',query:{'limit':'20','offset':'$offset'}); final rows=j['data']; if(rows is! List)return const []; return rows.whereType<Map>().map((x)=>CommentItem.fromJson(Map<String,dynamic>.from(x))).toList(); }
  Future<List<CommentItem>> replies(String id,{int offset=0}) async { final j=await _client.getJson('/comments/$id/replies',query:{'limit':'20','offset':'$offset'}); final rows=j['data']; if(rows is! List)return const []; return rows.whereType<Map>().map((x)=>CommentItem.fromJson(Map<String,dynamic>.from(x))).toList(); }
  Future<void> addComment(String type,String id,String body) async { final c=await AuthenticatedClient.create(); try{await c.postJson('/content/$type/$id/comments',body:{'body':body});}finally{c.dispose();} }
  Future<void> addReply(String id,String body) async { final c=await AuthenticatedClient.create(); try{await c.postJson('/comments/$id/replies',body:{'body':body});}finally{c.dispose();} }
  Future<void> react(String type,String id,String reaction) async { final c=await AuthenticatedClient.create(); try{await c.postJson('/content/$type/$id/reactions',body:{'reaction':reaction});}finally{c.dispose();} }
  Future<void> deleteComment(String id) async { final c=await AuthenticatedClient.create(); try{await c.deleteJson('/comments/$id');}finally{c.dispose();} }
}
