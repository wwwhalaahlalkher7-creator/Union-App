import 'api_client.dart';
import '../storage/auth_storage.dart';
import '../constants/app_constants.dart';

class AuthenticatedClient {
  AuthenticatedClient._();

  static Future<ApiClient> create() async {
    final storage = await AuthStorage.create();
    return ApiClient(
      baseUrl: AppConstants.apiBaseUrl,
      authStorage: storage,
    );
  }
}
