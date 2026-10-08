import '../../core/network/api_client.dart';

class EinoRepository {
  EinoRepository(this._client);

  final ApiClient _client;

  Future<EinoChatResponse> chat({required String prompt, String context = '', String? conversationId}) async {
    final json = await _client.postJson('/api/v1/eino/chat', body: {
      'message': prompt,
      if (context.trim().isNotEmpty) 'context': context,
      if (conversationId != null && conversationId.trim().isNotEmpty) 'conversationId': conversationId,
    });
    final data = json['data'];
    if (data is Map && data['message'] != null) {
      return EinoChatResponse(
        data['message'].toString().trim(),
        data['conversationId']?.toString(),
        sources: data['sources'] is List ? (data['sources'] as List).whereType<Map>().map((v) => EinoSource.fromJson(Map<String, dynamic>.from(v))).toList(growable: false) : const [],
        grounded: data['grounding'] is Map,
      );
    }
    throw const ApiException('No valid Eino response was received.');
  }

  Future<String> createConversation({String? title}) async {
    final json = await _client.postJson('/api/v1/eino/chats', body: {
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
    });
    final data = json['data'];
    if (data is Map && data['id'] != null) return data['id'].toString();
    throw const ApiException('No valid Eino conversation was created.');
  }

  Future<List<EinoConversation>> conversations({int limit = 30}) async {
    final json = await _client.getJson('/api/v1/eino/chats', query: {'limit': '$limit'}, forceRefresh: true);
    final data = json['data'];
    final values = data is Map && data['conversations'] is List ? data['conversations'] as List : const [];
    return values.whereType<Map>().map((v) => EinoConversation.fromJson(Map<String, dynamic>.from(v))).toList(growable: false);
  }

  Future<EinoConversationDetail> conversation(String id) async {
    final json = await _client.getJson('/api/v1/eino/chats/$id/messages', forceRefresh: true);
    final data = json['data'];
    if (data is Map) return EinoConversationDetail.fromJson(Map<String, dynamic>.from(data));
    throw const ApiException('No valid Eino conversation was received.');
  }

  Future<void> deleteConversation(String id) async {
    await _client.deleteJson('/api/v1/eino/chats/$id');
  }

  Future<void> appendConversationMessage({required String conversationId, required bool user, required String content}) async {
    await _client.postJson('/api/v1/eino/chats/$conversationId/messages', body: {
      'role': user ? 'user' : 'assistant',
      'content': content,
    });
  }

  Future<EinoGeneratedImage> generateImage({required String prompt, int? seed}) async {
    final json = await _client.postJson('/api/v1/eino/image', body: {
      'prompt': prompt.trim(),
      if (seed != null) 'seed': seed,
    });
    final data = json['data'];
    if (data is Map && data['imageBase64'] != null) {
      return EinoGeneratedImage(
        base64: data['imageBase64'].toString(),
        contentType: data['contentType']?.toString() ?? 'image/jpeg',
        provider: data['provider']?.toString(),
        model: data['model']?.toString(),
      );
    }
    throw const ApiException('No valid generated image was received from Eino.');
  }

  Future<String> imageAnalysis({required String imageDataUrl, String prompt = 'حلل هذه الصورة بدقة، واقرأ النصوص والمخططات والعناصر المهمة فيها. إذا كانت أكاديمية فاشرح ما يظهر فيها دون اختلاق معلومات.', String? conversationId, String? attachmentName}) async {
    final json = await _client.postJson('/api/v1/eino/vision', body: {
      'image': imageDataUrl,
      'mode': prompt,
      if (conversationId != null && conversationId.trim().isNotEmpty) 'conversationId': conversationId,
      if (attachmentName != null && attachmentName.trim().isNotEmpty) 'attachmentName': attachmentName,
    });
    return _textFrom(json, 'No valid image analysis result was received from Eino.');
  }

  Future<String> vision({required String imageDataUrl, String mode = 'describe', String? conversationId, String? attachmentName}) => imageAnalysis(
    imageDataUrl: imageDataUrl,
    prompt: mode,
    conversationId: conversationId,
    attachmentName: attachmentName,
  );

  Future<String> fileAnalysis({required List<int> bytes, required String filename, required String contentType, String? conversationId, String? prompt}) async {
    final json = await _client.postMultipartBytes(
      '/api/v1/eino/file-analysis',
      bytes: bytes,
      filename: filename,
      fieldName: 'file',
      contentType: contentType,
      fields: {
        if (conversationId != null && conversationId.trim().isNotEmpty) 'conversationId': conversationId,
        if (prompt != null && prompt.trim().isNotEmpty) 'prompt': prompt.trim(),
      },
    );
    return _textFrom(json, 'No valid file analysis result was received from Eino.');
  }

  Future<String> longSummary({required String text, String? conversationId}) async {
    final json = await _client.postJson('/api/v1/eino/long-summary', body: {
      'text': text,
      if (conversationId != null && conversationId.trim().isNotEmpty) 'conversationId': conversationId,
    });
    return _textFrom(json, 'No valid long summary was received from Eino.');
  }

  Future<String> ocr({required List<int> bytes, required String filename, required String contentType, String? conversationId}) async {
    final json = await _client.postMultipartBytes(
      '/api/v1/eino/ocr',
      bytes: bytes,
      filename: filename,
      fieldName: 'file',
      contentType: contentType,
      fields: {
        if (conversationId != null && conversationId.trim().isNotEmpty) 'conversationId': conversationId,
      },
    );
    return _textFrom(json, 'No valid document analysis result was received from Eino.');
  }

  Future<String> stt({required List<int> bytes, required String filename, required String contentType, String language = 'ar'}) async {
    final json = await _client.postMultipartBytes(
      '/api/v1/eino/stt',
      bytes: bytes,
      filename: filename,
      fieldName: 'file',
      contentType: contentType,
      fields: {'language': language},
    );
    return _textFrom(json, 'No valid speech transcription was received.');
  }

  Future<EinoTtsAudio?> tts({required String text, String? voice}) async {
    final json = await _client.postJson('/api/v1/eino/tts', body: {
      'text': text,
      if (voice != null && voice.trim().isNotEmpty) 'voice': voice.trim(),
    });
    final data = json['data'];
    if (data is Map) {
      final url = data['audioUrl'] ?? data['url'] ?? data['audio_url'];
      final base64 = data['audioBase64'] ?? data['audio_base64'];
      if (url != null || base64 != null) {
        return EinoTtsAudio(
          url: url?.toString(),
          base64: base64?.toString(),
          contentType: data['contentType']?.toString() ?? 'audio/mpeg',
        );
      }
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
    throw const ApiException('No valid Eino memory response was received.');
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


class EinoTtsAudio {
  const EinoTtsAudio({this.url, this.base64, this.contentType = 'audio/mpeg'});
  final String? url;
  final String? base64;
  final String contentType;
}

class EinoGeneratedImage {
  const EinoGeneratedImage({required this.base64, required this.contentType, this.provider, this.model});
  final String base64;
  final String contentType;
  final String? provider;
  final String? model;
}

class EinoChatResponse {
  const EinoChatResponse(this.message, this.conversationId, {this.sources = const [], this.grounded = false});
  final String message;
  final String? conversationId;
  final List<EinoSource> sources;
  final bool grounded;
}

class EinoSource {
  const EinoSource({this.title, this.url, this.materialId, this.subjectId});
  final String? title;
  final String? url;
  final String? materialId;
  final String? subjectId;
  factory EinoSource.fromJson(Map<String, dynamic> json) => EinoSource(
    title: json['title']?.toString(),
    url: json['url']?.toString(),
    materialId: json['materialId']?.toString(),
    subjectId: json['subjectId']?.toString(),
  );
}

class EinoConversation {
  const EinoConversation({required this.id, required this.title, this.lastMessage, this.updatedAt});
  final String id;
  final String title;
  final String? lastMessage;
  final String? updatedAt;
  factory EinoConversation.fromJson(Map<String, dynamic> json) => EinoConversation(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'محادثة Eino',
    lastMessage: json['lastMessage']?.toString(),
    updatedAt: json['updatedAt']?.toString(),
  );
}

class EinoConversationMessage {
  const EinoConversationMessage({required this.user, required this.content, this.createdAt});
  final bool user;
  final String content;
  final String? createdAt;
  factory EinoConversationMessage.fromJson(Map<String, dynamic> json) => EinoConversationMessage(
    user: json['role']?.toString() == 'user',
    content: json['content']?.toString() ?? '',
    createdAt: json['createdAt']?.toString(),
  );
}

class EinoConversationDetail {
  const EinoConversationDetail({required this.conversation, required this.messages});
  final EinoConversation conversation;
  final List<EinoConversationMessage> messages;
  factory EinoConversationDetail.fromJson(Map<String, dynamic> json) {
    final c = json['conversation'];
    final values = json['messages'];
    return EinoConversationDetail(
      conversation: EinoConversation.fromJson(c is Map ? Map<String, dynamic>.from(c) : const {}),
      messages: values is List ? values.whereType<Map>().map((v) => EinoConversationMessage.fromJson(Map<String, dynamic>.from(v))).toList(growable: false) : const [],
    );
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
