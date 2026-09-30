import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device is actually without a network interface.
///
/// Connectivity type alone does not prove Internet access, so ApiClient still
/// treats request failures as the final authority. This class only prevents
/// needless API calls when Wi-Fi/mobile data are explicitly unavailable.
class OfflineState {
  OfflineState._() {
    _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        markOnline();
      } else {
        markOffline();
      }
    });
  }

  static final OfflineState instance = OfflineState._();

  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasNetworkInterface() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      // If the connectivity plugin itself is unavailable, let the HTTP layer
      // make the request and decide based on the actual network result.
      return true;
    }
  }

  void markOnline() => isOffline.value = false;
  void markOffline() => isOffline.value = true;
}
