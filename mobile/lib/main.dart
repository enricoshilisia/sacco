import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/client_context.dart';
import 'core/secure_store.dart';
import 'core/session.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/password_change_screen.dart';
import 'screens/sacco_code_screen.dart';
import 'screens/unlock_screen.dart';
import 'theme.dart';
import 'widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ClientContext.instance.init();
  final session = Session(SecureStore())..bootstrap();
  runApp(ChangeNotifierProvider.value(value: session, child: const SaccoApp()));
}

class SaccoApp extends StatefulWidget {
  const SaccoApp({super.key});

  @override
  State<SaccoApp> createState() => _SaccoAppState();
}

class _SaccoAppState extends State<SaccoApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  SessionStage? _lastStage;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    // Leaving the signed-in app (log out, session expired, change SACCO):
    // close every screen opened on top of it (e.g. Profile) so the login
    // screen is actually what's showing, not left underneath them.
    if (_lastStage == SessionStage.ready && session.stage != SessionStage.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      });
    }
    _lastStage = session.stage;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: session.locale,
      // One animated glass backdrop behind every route (scaffolds are transparent).
      builder: (context, child) => GlassBackground(child: child ?? const SizedBox()),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: switch (session.stage) {
        SessionStage.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
        SessionStage.needsSacco => const SaccoCodeScreen(),
        SessionStage.needsLogin => const LoginScreen(),
        SessionStage.locked => const UnlockScreen(),
        // A temporary password (new member, or an admin reset): choose your own first.
        SessionStage.mustChangePassword => const PasswordChangeScreen(),
        // Keyed by SACCO so switching SACCOs rebuilds every tab from scratch
        // rather than showing the previous SACCO's cached data.
        SessionStage.ready => HomeShell(key: ValueKey(session.sacco?.code)),
      },
    );
  }
}
