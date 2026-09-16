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

  Future<String> vision({required String imageDataUrl, String mode = 'describe'}) async {
    final json = await _client.postJson('/api/v1/eino/vision', body: {
      'image': imageDataUrl,
      'mode': mode,
    });
    return _textFrom(json, 'لم تصل نتيجة صالحة لتحليل الصورة من Eino.');
  }

  Future<String> ocr({required List<int> bytes, required String filename, required String contentType}) async {
    final json = await _client.postMultipartBytes(
      '/api/v1/eino/ocr',
      bytes: bytes,
      filename: filename,
      fieldName: 'file',
      contentType: contentType,
    );
    return _textFrom(json, 'لم تصل نتيجة صالحة لقراءة المستند من Eino.');
  }

  Future<String> stt({required List<int> bytes, required String filename, required String contentType, String language = 'auto'}) async {
    final json = await _client.postMultipartBytes(
      '/api/v1/eino/stt',
      bytes: bytes,
      filename: filename,
      fieldName: 'file',
      contentType: contentType,
      fields: {'language': language},
    );
    return _textFrom(json, 'لم يصل نص صالح من التسجيل الصوتي.');
  }

  Future<String?> tts({required String text, String voice = 'af_heart'}) async {
    final json = await _client.postJson('/api/v1/eino/tts', body: {
      'text': text,
      'voice': voice,
    });
    final data = json['data'];
    if (data is Map) {
      final url = data['audioUrl'] ?? data['url'] ?? data['audio_url'];
      return url?.toString();
    }
    return null;
  }

  String _textFrom(Map<String, dynamic> json, String fallback) {
    final data = json['data'];
    if (data is Map) {
      final value = data['text'] ?? data['transcript'] ?? data['message'];
      if (value != null && value.toString().trim().isNotEmpty) return value.toString().trim();
    }
    throw ApiException(fallback);
  }
}
