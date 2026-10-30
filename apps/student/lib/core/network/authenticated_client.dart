import '../di/app_dependencies.dart';
import 'api_client.dart';

/// Compatibility facade for older integrations.
///
/// New code should use [AppDependencies.instance.apiClient] directly.
@Deprecated('Use AppDependencies.instance.apiClient instead.')
class AuthenticatedClient {
  AuthenticatedClient._();

  static Future<ApiClient> create() async {
    final dependencies = AppDependencies.instance;
    await dependencies.initialize();
    return dependencies.apiClient;
  }
}
