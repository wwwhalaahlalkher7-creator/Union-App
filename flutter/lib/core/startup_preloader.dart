import 'api_client.dart';

/// Warms only public, read-only data that is useful immediately after launch.
/// Failures are intentionally ignored: startup must never depend on the network.
class StartupPreloader {
  const StartupPreloader(this._client);

  final ApiClient _client;

  Future<void> warmPublicCache() async {
    const paths = <String>[
      '/api/v1/public/news',
      '/api/v1/public/events',
    ];
    await Future.wait(
      paths.map(
        (path) => _client
            .getJson(path, cacheTtl: const Duration(seconds: 45))
            .timeout(const Duration(seconds: 3))
            .catchError((_) => <String, dynamic>{}),
      ),
    );
  }
}
