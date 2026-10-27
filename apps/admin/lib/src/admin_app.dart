import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api_service.dart';
import 'session_store.dart';
import 'shell.dart';
import 'design_system/trinex_theme.dart';

class TrinexAdminApp extends StatefulWidget {
  const TrinexAdminApp({super.key});

  @override
  State<TrinexAdminApp> createState() => _TrinexAdminAppState();
}

class _TrinexAdminAppState extends State<TrinexAdminApp> {
  late final SessionStore _sessionStore = SessionStore();
  late final ApiService _api = ApiService(sessionStore: _sessionStore);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRINEX Admin',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: TrinexTheme.light,
      home: AdminShell(api: _api, sessionStore: _sessionStore),
    );
  }
}
