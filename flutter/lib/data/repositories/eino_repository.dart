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

  Future<EinoCapabilities> capabilities() async {
    final json = await _client.getJson('/api/v1/eino/capabilities');
    return EinoCapabilities.fromJson(json);
  }


  Future<List<EinoLocalModel>> models() async {
    final json = await _client.getJson('/api/v1/eino/models');
    final data = json['data'];
    final values = data is Map && data['models'] is List ? data['models'] as List : const [];
    return values.whereType<Map>().map((value) => EinoLocalModel.fromJson(Map<String, dynamic>.from(value))).toList(growable: false);
  }

  Future<List<EinoMemory>> memories({int limit = 30}) async {
    final json = await _client.getJson('/api/v1/eino/memory', query: {'limit': '$limit'});
    final data = json['data'];
    final values = data is Map && data['memories'] is List ? data['memories'] as List : const [];
    return values.whereType<Map>().map((value) => EinoMemory.fromJson(Map<String, dynamic>.from(value))).toList(growable: false);
  }

  Future<EinoMemory> remember({required String content, String category = 'general'}) async {
    final json = await _client.postJson('/api/v1/eino/memory', body: {'content': content, 'category': category});
    final data = json['data'];
    if (data is Map) return EinoMemory.fromJson(Map<String, dynamic>.from(data));
    throw const ApiException('لم تصل استجابة صالحة من ذاكرة Eino.');
  }

  Future<void> forgetMemory(String id) async {
    await _client.deleteJson('/api/v1/eino/memory/$id');
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


class EinoCapabilities {
  const EinoCapabilities({
    required this.online,
    required this.provider,
    required this.providers,
    required this.capabilities,
    required this.model,
    required this.offlineAvailable,
    required this.offlineReason,
  });

  final bool online;
  final String? provider;
  final Map<String, bool> providers;
  final List<String> capabilities;
  final String model;
  final bool offlineAvailable;
  final String? offlineReason;

  factory EinoCapabilities.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final providerMap = map['providers'];
    final offline = map['offline'];
    return EinoCapabilities(
      online: map['online'] == true,
      provider: map['provider']?.toString(),
      providers: providerMap is Map
          ? providerMap.map((key, value) => MapEntry(key.toString(), value == true))
          : const <String, bool>{},
      capabilities: (map['capabilities'] is List)
          ? (map['capabilities'] as List).map((value) => value.toString()).toList(growable: false)
          : const <String>[],
      model: map['model']?.toString() ?? '',
      offlineAvailable: offline is Map && offline['available'] == true,
      offlineReason: offline is Map ? offline['reason']?.toString() : null,
    );
  }
}

class EinoMemory {
  const EinoMemory({required this.id, required this.content, required this.category, this.source, this.createdAt, this.updatedAt});

  final String id;
  final String content;
  final String category;
  final String? source;
  final String? createdAt;
  final String? updatedAt;

  factory EinoMemory.fromJson(Map<String, dynamic> json) => EinoMemory(
        id: json['id']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        category: json['category']?.toString() ?? 'general',
        source: json['source']?.toString(),
        createdAt: json['createdAt']?.toString(),
        updatedAt: json['updatedAt']?.toString(),
      );
}


class EinoLocalModel {
  const EinoLocalModel({
    required this.id,
    required this.name,
    required this.format,
    required this.quantization,
    required this.approximateSizeGb,
    required this.recommendedRamGb,
    required this.architecture,
    required this.capabilities,
    required this.status,
    this.downloadUrl,
    this.sha256,
    this.source,
    this.license,
  });

  final String id;
  final String name;
  final String format;
  final String quantization;
  final double approximateSizeGb;
  final int recommendedRamGb;
  final List<String> architecture;
  final List<String> capabilities;
  final String status;
  final String? downloadUrl;
  final String? sha256;
  final String? source;
  final String? license;

  factory EinoLocalModel.fromJson(Map<String, dynamic> json) => EinoLocalModel(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    format: json['format']?.toString() ?? 'GGUF',
    quantization: json['quantization']?.toString() ?? '',
    approximateSizeGb: (json['approximateSizeGb'] as num?)?.toDouble() ?? 0,
    recommendedRamGb: (json['recommendedRamGb'] as num?)?.toInt() ?? 0,
    architecture: (json['architecture'] is List) ? (json['architecture'] as List).map((v) => v.toString()).toList(growable: false) : const [],
    capabilities: (json['capabilities'] is List) ? (json['capabilities'] as List).map((v) => v.toString()).toList(growable: false) : const [],
    status: json['status']?.toString() ?? 'catalog',
    downloadUrl: json['downloadUrl']?.toString(),
    sha256: json['sha256']?.toString(),
    source: json['source']?.toString(),
    license: json['license']?.toString(),
  );
}
