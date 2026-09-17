import 'dart:async';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/eino_repository.dart';

/// Owns downloaded GGUF files. The server is the source of truth for the
/// catalog; this service owns only the user's local model files and state.
class EinoLocalModelStore {
  static const _indexKey = 'eino.local.models.v1';

  Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/eino/models');
    if (!directory.existsSync()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> fileFor(EinoLocalModel model) async {
    final directory = await _directory();
    final safeId = model.id.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return File('${directory.path}/$safeId.gguf');
  }

  Future<bool> isInstalled(EinoLocalModel model) async {
    final file = await fileFor(model);
    return file.existsSync() && file.lengthSync() > 0;
  }

  Future<bool> verifyIntegrity(EinoLocalModel model) async {
    final expected = model.sha256?.trim().toLowerCase();
    if (expected == null || expected.isEmpty) return true;
    final file = await fileFor(model);
    if (!file.existsSync()) return false;
    final digest = await _sha256(file);
    return digest.toLowerCase() == expected;
  }

  Future<String> _sha256(File file) async {
    final sink = AccumulatorSink<Digest>();
    final converter = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) converter.add(chunk);
    converter.close();
    return sink.events.single.toString();
  }

  Future<List<String>> installedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_indexKey) ?? const [];
  }

  Future<void> markInstalled(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = {...?prefs.getStringList(_indexKey), id}.toList()..sort();
    await prefs.setStringList(_indexKey, ids);
  }

  Future<void> remove(EinoLocalModel model) async {
    final file = await fileFor(model);
    if (file.existsSync()) await file.delete();
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_indexKey) ?? const []).where((id) => id != model.id).toList();
    await prefs.setStringList(_indexKey, ids);
  }
}

class EinoLocalModelDownload {
  const EinoLocalModelDownload({required this.file, required this.bytes, required this.totalBytes});
  final File file;
  final int bytes;
  final int totalBytes;
  double get progress => totalBytes <= 0 ? 0 : bytes / totalBytes;
}

class EinoLocalModelDownloader {
  EinoLocalModelDownloader(this._store);
  final EinoLocalModelStore _store;

  Future<File> download(
    EinoLocalModel model, {
    required String url,
    String? sha256,
    void Function(EinoLocalModelDownload progress)? onProgress,
  }) async {
    final destination = await _store.fileFor(model);
    final partial = File('${destination.path}.part');
    final existing = partial.existsSync() ? partial.lengthSync() : 0;
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      if (existing > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
      final response = await request.close();
      final append = existing > 0 && response.statusCode == HttpStatus.partialContent;
      final start = append ? existing : 0;
      final totalHeader = response.headers.value(HttpHeaders.contentLengthHeader);
      final parsedLength = totalHeader == null ? null : int.tryParse(totalHeader);
      final total = parsedLength == null ? -1 : start + parsedLength.clamp(0, 1 << 60);
      final sink = partial.openWrite(mode: append ? FileMode.append : FileMode.write);
      var received = start;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(EinoLocalModelDownload(file: partial, bytes: received, totalBytes: total));
        }
      } finally {
        await sink.close();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (partial.existsSync()) await partial.delete();
        throw const EinoLocalException('تعذر تنزيل النموذج من المصدر المحدد.');
      }
      if (sha256 != null && sha256.trim().isNotEmpty) {
        final digest = await _sha256(partial);
        if (digest.toLowerCase() != sha256.trim().toLowerCase()) {
          await partial.delete();
          throw const EinoLocalException('فشل التحقق من سلامة ملف النموذج (SHA-256).');
        }
      }
      if (destination.existsSync()) await destination.delete();
      await partial.rename(destination.path);
      await _store.markInstalled(model.id);
      return destination;
    } on SocketException catch (e) {
      throw EinoLocalException('تعذر الاتصال أثناء تنزيل النموذج.', e);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _sha256(File file) async {
    final sink = AccumulatorSink<Digest>();
    final converter = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      converter.add(chunk);
    }
    converter.close();
    return sink.events.single.toString();
  }

}

class EinoLocalEngine {
  EinoLocalEngine();

  LlamaController? _controller;
  String? _loadedModelId;

  bool get isLoaded => _controller != null;
  String? get loadedModelId => _loadedModelId;

  Future<GpuInfo> detectHardware() async {
    final controller = _controller ??= LlamaController();
    return controller.detectGpu();
  }

  Future<void> load(EinoLocalModel model, File file) async {
    if (!Platform.isAndroid) throw const EinoLocalException('المحرك المحلي متاح حاليًا على Android فقط.');
    if (!file.existsSync()) throw const EinoLocalException('ملف النموذج غير موجود على الجهاز.');
    if (_loadedModelId == model.id && _controller != null) return;

    // Never keep two multi-gigabyte models resident at the same time.
    final previous = _controller;
    _controller = null;
    _loadedModelId = null;
    await previous?.dispose();

    final controller = LlamaController();
    try {
      final gpu = await controller.detectGpu();
      await controller.loadModel(
        modelPath: file.path,
        threads: 4,
        contextSize: 4096,
        gpuLayers: gpu.recommendedGpuLayers,
      );
      _controller = controller;
      _loadedModelId = model.id;
    } catch (e) {
      await controller.dispose();
      throw EinoLocalException('تعذر تحميل النموذج المحلي.', e);
    }
  }

  Future<EinoLocalBenchmark> benchmark() async {
    final controller = _controller;
    final modelId = _loadedModelId;
    if (controller == null || modelId == null) {
      throw const EinoLocalException('حمّل نموذجًا محليًا أولًا.');
    }
    final stopwatch = Stopwatch()..start();
    var tokens = 0;
    var firstTokenMs = -1;
    await for (final token in controller.generate(
      prompt: 'أجب بكلمة واحدة: جاهز',
      maxTokens: 8,
      temperature: 0.0,
    )) {
      tokens++;
      if (firstTokenMs < 0) firstTokenMs = stopwatch.elapsedMilliseconds;
      if (token.isEmpty) continue;
    }
    stopwatch.stop();
    final totalMs = stopwatch.elapsedMilliseconds;
    return EinoLocalBenchmark(
      modelId: modelId,
      tokens: tokens,
      firstTokenMs: firstTokenMs,
      totalMs: totalMs,
      tokensPerSecond: totalMs <= 0 ? 0 : tokens * 1000 / totalMs,
    );
  }

  Stream<String> generateChat({required String systemPrompt, required String prompt, int maxTokens = 512}) {
    final controller = _controller;
    if (controller == null) {
      return Stream<String>.error(const EinoLocalException('لم يتم تحميل نموذج محلي بعد.'));
    }
    return controller.generateChat(
      messages: [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: prompt),
      ],
      temperature: 0.7,
      maxTokens: maxTokens,
    );
  }

  Future<void> stop() async => _controller?.stop();

  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    _loadedModelId = null;
    await controller?.dispose();
  }
}


class EinoLocalBenchmark {
  const EinoLocalBenchmark({
    required this.modelId,
    required this.tokens,
    required this.firstTokenMs,
    required this.totalMs,
    required this.tokensPerSecond,
  });

  final String modelId;
  final int tokens;
  final int firstTokenMs;
  final int totalMs;
  final double tokensPerSecond;
}

class EinoLocalException implements Exception {
  const EinoLocalException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => message;
}

