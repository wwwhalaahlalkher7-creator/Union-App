import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

/// Keeps an app-private copy for offline reading and, on Android 10+, a second
/// copy in the student's public Download/TRINEX folder.
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
      final items = decoded
          .whereType<Map>()
          .map((item) => DownloadedMaterial.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.materialId.isNotEmpty && item.filePath.isNotEmpty)
          .where((item) => File(item.filePath).existsSync())
          .toList(growable: false);
      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<SaveMaterialResult> save({
    required String ownerKey,
    required String materialId,
    required String title,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) throw const FileSystemException('ملف PDF فارغ.');
    final directory = await _directory(ownerKey);
    final safeId = materialId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${directory.path}/$safeId.pdf');
    await file.writeAsBytes(bytes, flush: true);

    final safeTitle = title
        .replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final publicName = '${safeTitle.isEmpty ? 'material' : safeTitle}_$safeId.pdf';
    var savedPublic = false;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        savedPublic = await _channel.invokeMethod<bool>('savePdf', {
          'filename': publicName,
          'bytes': bytes,
        }) ?? false;
      } on PlatformException {
        savedPublic = false;
      } on MissingPluginException {
        savedPublic = false;
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
    return SaveMaterialResult(item: item, savedToPublicDownloads: savedPublic);
  }
}
