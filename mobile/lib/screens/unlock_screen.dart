import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  void _unlock() => context.read<Session>().unlock(context.l10n.unlockReason);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Appear(child: InukaLogo(size: 120))),
              const SizedBox(height: 16),
              Text(session.sacco?.name ?? context.l10n.appTitle,
                  textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              Icon(Icons.fingerprint, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 32),
              FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.lock_open), label: Text(l10n.unlockButton)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => session.logout(), child: Text(l10n.usePassword)),
            ],
          ),
        ),
      ),
    );
  }
}
