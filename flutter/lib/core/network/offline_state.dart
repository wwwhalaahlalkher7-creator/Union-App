import 'package:flutter/foundation.dart';

class OfflineState {
  OfflineState._();
  static final OfflineState instance = OfflineState._();

  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

  void markOnline() => isOffline.value = false;
  void markOffline() => isOffline.value = true;
}
