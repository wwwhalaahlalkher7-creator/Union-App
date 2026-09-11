import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../storage/auth_storage.dart';
import '../constants/app_constants.dart';

class AuthenticatedClient {
  AuthenticatedClient._();

  static Future<ApiClient> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ApiClient(
      baseUrl: AppConstants.apiBaseUrl,
      authStorage: AuthStorage(prefs),
    );
  }
}
