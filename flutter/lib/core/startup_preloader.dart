import 'dart:async';

import 'constants/app_constants.dart';
import 'network/api_client.dart';

/// Warms only public, read-only data that is useful immediately after launch.
/// Failures are intentionally ignored: startup must never depend on the network.
class StartupPreloader {
  const StartupPreloader();

  Future<void> warmPublicCache() async {
    final client = ApiClient(baseUrl: AppConstants.apiBaseUrl);
    const paths = <String>[
      '/api/v1/public/news',
      '/api/v1/public/announcements',
      '/api/v1/public/events',
      '/api/v1/public/activities',
    ];
    try {
      await Future.wait(
        paths.map((path) => client
            .getJson(path, cacheTtl: const Duration(seconds: 45))
            .timeout(const Duration(seconds: 3))
            .catchError((_) => <String, dynamic>{})),
      );
    } finally {
      client.dispose();
    }
  }
}
