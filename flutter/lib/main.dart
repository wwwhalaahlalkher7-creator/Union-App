import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/splash/trinex_splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _TrinexBootstrap());
}

class _TrinexBootstrap extends StatefulWidget {
  const _TrinexBootstrap();

  @override
  State<_TrinexBootstrap> createState() => _TrinexBootstrapState();
}

class _TrinexBootstrapState extends State<_TrinexBootstrap> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    if (_ready) return const TrinexApp();
    return TrinexSplashScreen(
      onFinished: () => setState(() => _ready = true),
    );
  }
}
