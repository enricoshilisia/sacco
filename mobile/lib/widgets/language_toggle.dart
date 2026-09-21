import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';

/// English / Kiswahili switch, available before login too.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final current = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.translate),
      initialValue: current,
      onSelected: (code) => context.read<Session>().setLocale(Locale(code)),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'sw', child: Text('Kiswahili')),
      ],
    );
  }
}
