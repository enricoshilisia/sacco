import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../core/api_client.dart';
import '../core/sacco_api.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/language_toggle.dart';

class SaccoCodeScreen extends StatefulWidget {
  const SaccoCodeScreen({super.key});

  @override
  State<SaccoCodeScreen> createState() => _SaccoCodeScreenState();
}

class _SaccoCodeScreenState extends State<SaccoCodeScreen> {
  final _code = TextEditingController(text: AppConfig.defaultSaccoCode);
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Single-SACCO build: connect straight away, no code to type.
    if (AppConfig.isSingleSacco) WidgetsBinding.instance.addPostFrameCallback((_) => _submit());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sacco = await lookupSacco(_code.text);
      if (!mounted) return;
      await context.read<Session>().chooseSacco(sacco);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.isNotFound ? context.l10n.saccoNotFound : errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(actions: const [LanguageToggle()]),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Appear(child: InukaLogo(size: 128)),
                const SizedBox(height: 20),
                Appear(
                  index: 1,
                  child: Text(l10n.appTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ),
                const SizedBox(height: 4),
                Appear(index: 1, child: Text(l10n.brandTagline, style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
                const SizedBox(height: 28),
                Appear(
                  index: 2,
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: AppConfig.isSingleSacco && _error == null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(l10n.connecting),
                            ]),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(l10n.findSaccoTitle,
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(l10n.findSaccoBody, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _code,
                                autofocus: !AppConfig.isSingleSacco,
                                autocorrect: false,
                                textInputAction: TextInputAction.go,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: l10n.saccoCode,
                                  errorText: _error,
                                  prefixIcon: const Icon(Icons.apartment_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(AppConfig.isSingleSacco ? l10n.retry : l10n.continueLabel),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
