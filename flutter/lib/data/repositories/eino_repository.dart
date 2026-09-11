import '../../core/network/api_client.dart';

class EinoRepository {
  EinoRepository(this._client);

  final ApiClient _client;

  Future<String> chat({required String prompt, String context = ''}) async {
    final json = await _client.postJson('/api/v1/eino/chat', body: {
      'message': prompt,
      if (context.trim().isNotEmpty) 'context': context,
    });
    final data = json['data'];
    if (data is Map && data['message'] != null) return data['message'].toString().trim();
    throw const ApiException('لم تصل إجابة صالحة من Eino.');
  }
}
