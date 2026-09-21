import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/secure_store.dart';
import 'core/session.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/sacco_code_screen.dart';
import 'screens/unlock_screen.dart';
import 'theme.dart';
import 'widgets/glass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(SecureStore())..bootstrap();
  runApp(ChangeNotifierProvider.value(value: session, child: const SaccoApp()));
}

class SaccoApp extends StatelessWidget {
  const SaccoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return MaterialApp(
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
        // Keyed by SACCO so switching SACCOs rebuilds every tab from scratch
        // rather than showing the previous SACCO's cached data.
        SessionStage.ready => HomeShell(key: ValueKey(session.sacco?.code)),
      },
    );
  }
}
