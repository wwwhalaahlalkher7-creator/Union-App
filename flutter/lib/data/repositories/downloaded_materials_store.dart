import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadedMaterial {
  const DownloadedMaterial({
    required this.materialId,
    required this.title,
    required this.filePath,
    required this.publicFileName,
    required this.downloadedAt,
  });

  final String materialId;
  final String title;
  final String filePath;
  final String publicFileName;
  final String downloadedAt;

  File get file => File(filePath);

  Map<String, dynamic> toJson() => {
    'materialId': materialId,
    'title': title,
    'filePath': filePath,
    'publicFileName': publicFileName,
    'downloadedAt': downloadedAt,
  };

  factory DownloadedMaterial.fromJson(Map<String, dynamic> json) => DownloadedMaterial(
    materialId: '${json['materialId'] ?? ''}',
    title: '${json['title'] ?? 'ملف دراسي'}',
    filePath: '${json['filePath'] ?? ''}',
    publicFileName: '${json['publicFileName'] ?? ''}',
    downloadedAt: '${json['downloadedAt'] ?? ''}',
  );
}

class SaveMaterialResult {
  const SaveMaterialResult({required this.item, required this.savedToPublicDownloads});
  final DownloadedMaterial item;
  final bool savedToPublicDownloads;
}

/// Keeps exactly one app-private copy for offline reading. The viewer opens this
/// same file directly, avoiding duplicate storage in the public Downloads folder.
class DownloadedMaterialsStore {
  static const _metadataKey = 'trinex_downloaded_materials_v1';
  static const MethodChannel _channel = MethodChannel('app.trinex/downloads');

  String _safeOwner(String ownerKey) {
    final safe = ownerKey.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'guest' : safe;
  }

  String _keyForOwner(String ownerKey) => '${_metadataKey}_${_safeOwner(ownerKey)}';

  Future<Directory> _directory(String ownerKey) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/TRINEX/${_safeOwner(ownerKey)}');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<List<DownloadedMaterial>> list({required String ownerKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForOwner(ownerKey));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final candidates = decoded
          .whereType<Map>()
          .map((item) => DownloadedMaterial.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.materialId.isNotEmpty && item.filePath.isNotEmpty);
      final validItems = <DownloadedMaterial>[];
      for (final item in candidates) {
        if (await isValidPdfFile(item.file)) validItems.add(item);
      }
      return validItems;
    } catch (_) {
      return const [];
    }
  }

  Future<bool> isValidPdfFile(File file) async {
    try {
      if (!await file.exists() || await file.length() < 5) return false;
      final prefix = await file.openRead(0, 1024).fold<List<int>>(
        <int>[],
        (collected, chunk) => collected..addAll(chunk),
      );
      return _hasPdfHeader(Uint8List.fromList(prefix));
    } on FileSystemException {
      return false;
    }
  }

  Future<DownloadedMaterial?> findByMaterialId({
    required String ownerKey,
    required String materialId,
  }) async {
    for (final item in await list(ownerKey: ownerKey)) {
      if (item.materialId != materialId) continue;
      if (await isValidPdfFile(item.file)) return item;
    }
    return null;
  }

  Future<SaveMaterialResult> save({
    required String ownerKey,
    required String materialId,
    required String title,
    required Uint8List bytes,
  }) async {
    if (!_hasPdfHeader(bytes)) {
      throw const FileSystemException('البيانات المستلمة ليست ملف PDF صالحًا.');
    }
    final directory = await _directory(ownerKey);
    final safeId = materialId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${directory.path}/$safeId.pdf');
    final temporaryFile = File('${directory.path}/$safeId.pdf.part');
    await temporaryFile.writeAsBytes(bytes, flush: true);
    // Replace only after the new copy has been fully written, so an interrupted
    // write cannot leave the previously downloaded PDF truncated.
    if (await file.exists()) await file.delete();
    await temporaryFile.rename(file.path);

    final safeTitle = title
        .replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final publicName = '${safeTitle.isEmpty ? 'material' : safeTitle}_$safeId.pdf';
    // Remove a duplicate created by older app versions, if present. New downloads
    // are stored only in the app-private directory and opened from that same file.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('deletePublicPdf', {'filename': publicName});
      } on PlatformException {
        // Cleanup is best-effort; it must not fail a valid app-private download.
      } on MissingPluginException {
        // Older platform builds may not implement cleanup yet.
      }
    }

    final item = DownloadedMaterial(
      materialId: materialId,
      title: title,
      filePath: file.path,
      publicFileName: publicName,
      downloadedAt: DateTime.now().toIso8601String(),
    );
    final prefs = await SharedPreferences.getInstance();
    final existing = await list(ownerKey: ownerKey);
    final next = [item, ...existing.where((saved) => saved.materialId != materialId)];
    await prefs.setString(_keyForOwner(ownerKey), jsonEncode(next.map((saved) => saved.toJson()).toList()));
    return SaveMaterialResult(item: item, savedToPublicDownloads: false);
  }

  bool _hasPdfHeader(Uint8List bytes) {
    if (bytes.length < 5) return false;
    // The PDF specification permits a small amount of leading data before the
    // header, so inspect the first 1024 bytes rather than only bytes 0–4.
    final limit = bytes.length < 1024 ? bytes.length : 1024;
    for (var i = 0; i <= limit - 5; i++) {
      if (bytes[i] == 0x25 && // %
          bytes[i + 1] == 0x50 && // P
          bytes[i + 2] == 0x44 && // D
          bytes[i + 3] == 0x46 && // F
          bytes[i + 4] == 0x2D) { // -
        return true;
      }
    }
    return false;
  }
}
