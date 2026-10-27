import '../app_version.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';
import 'update_info.dart';

/// Reads the TRINEX update manifest from the API.
///
/// The old `/api/v1/version` endpoint is intentionally not used here: it can
/// contain legacy configuration values and must never be presented as a real
/// update source. The server-side manifest can later point to the official
/// TRINEX download page without requiring another app release.
class UpdateService {
  const UpdateService();

  Future<UpdateInfo?> check() async {
    final client = ApiClient(baseUrl: AppConstants.apiBaseUrl);
    try {
      final response = await client.getJson(
        '/api/v1/app/update',
        query: {
          'version': AppVersion.name,
          'build': AppVersion.build.toString(),
          'platform': 'android',
        },
        forceRefresh: true,
      );
      final data = response['data'];
      if (data is! Map) return null;

      final manifest = Map<String, dynamic>.from(data);
      final latest = manifest['latestVersion']?.toString().trim() ?? '';
      if (latest.isEmpty || !_isValidVersion(latest)) return null;

      return UpdateInfo(
        currentVersion: latest,
        minimumVersion: manifest['minimumVersion']?.toString(),
        updateUrl: manifest['downloadUrl']?.toString(),
        releaseNotes: manifest['releaseNotes']?.toString(),
      );
    } catch (_) {
      return null;
    } finally {
      client.dispose();
    }
  }

  bool isForceRequired(UpdateInfo info) {
    final minimum = info.minimumVersion;
    if (minimum == null || minimum.isEmpty || !_isValidVersion(minimum)) {
      return false;
    }
    return VersionComparator.compare(AppVersion.name, minimum) < 0;
  }

  bool isOptional(UpdateInfo info) {
    if (!_isValidVersion(info.currentVersion)) return false;
    if (VersionComparator.compare(info.currentVersion, AppVersion.name) <= 0) {
      return false;
    }
    return !isForceRequired(info);
  }

  bool _isValidVersion(String value) =>
      RegExp(r'^v?\d+\.\d+\.\d+(?:\+\d+)?$').hasMatch(value.trim());
}
