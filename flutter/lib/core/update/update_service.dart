import '../app_version.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';
import 'update_info.dart';

class UpdateService {
  const UpdateService();

  Future<UpdateInfo?> check() async {
    final client = ApiClient(baseUrl: AppConstants.apiBaseUrl);
    try {
      final response = await client.getJson('/api/v1/version');
      final data = response['data'];
      if (data is! Map) return null;
      return UpdateInfo(
        currentVersion: '${data['appVersion'] ?? ''}',
        minimumVersion: data['minimumAppVersion']?.toString(),
        updateUrl: data['updateUrl']?.toString(),
        releaseNotes: data['releaseNotes']?.toString(),
      );
    } catch (_) {
      return null;
    } finally {
      client.dispose();
    }
  }

  bool isForceRequired(UpdateInfo info) {
    final minimum = info.minimumVersion;
    if (minimum == null || minimum.isEmpty) return false;
    return VersionComparator.compare(AppVersion.name, minimum) < 0;
  }

  bool isOptional(UpdateInfo info) {
    if (VersionComparator.compare(info.currentVersion, AppVersion.name) <= 0) return false;
    return !isForceRequired(info);
  }
}
