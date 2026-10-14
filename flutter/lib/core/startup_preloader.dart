import 'network/api_client.dart';

/// Warms only public, read-only data that is useful immediately after launch.
/// Failures are intentionally ignored: startup must never depend on the network.
class StartupPreloader {
  const StartupPreloader(this._client);

  final ApiClient _client;

  Future<void> warmPublicCache() async {
    const paths = <String>[
      '/api/v1/public/news',
      '/api/v1/public/activities',
      '/api/v1/public/achievements',
    ];
    // Do not await these requests during startup. ApiClient coalesces identical
    // GETs with screen requests, so a screen opening immediately after launch
    // joins the same in-flight request rather than starting a duplicate.
    await Future.wait(
      paths.map((path) => _client
          .getJson(
            path,
            query: const {'limit': '50', 'offset': '0'},
            cacheTtl: path.endsWith('/achievements')
                ? const Duration(hours: 24)
                : const Duration(hours: 12),
          )
          .catchError((_) => <String, dynamic>{})),
    );
  }
}
