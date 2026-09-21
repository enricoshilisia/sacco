import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../core/api_client.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/language_toggle.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phone.text.trim().isEmpty || _password.text.isEmpty) return;
    final session = context.read<Session>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await session.login(_phone.text.trim(), _password.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      final l10n = context.l10n;
      setState(() {
        if (e.message == 'network') {
          _error = l10n.networkError;
        } else if (e.status == 401) {
          _error = l10n.loginError;
        } else {
          // e.g. "This SACCO's free trial has ended..." from the backend.
          _error = e.message.isNotEmpty ? e.message : l10n.loginError;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final session = context.watch<Session>();
    final sacco = session.sacco;
    return Scaffold(
      appBar: AppBar(actions: const [LanguageToggle()]),
      body: SafeArea(
        child: AutofillGroup(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Appear(child: InukaLogo(size: 112)),
                  const SizedBox(height: 16),
                  Appear(
                    index: 1,
                    child: Text(sacco?.name ?? l10n.appTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 24),
                  Appear(
                    index: 2,
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l10n.loginTitle, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          if (session.sessionExpired || session.noMemberLinked) ...[
                            const SizedBox(height: 12),
                            Text(
                              session.noMemberLinked ? l10n.noMemberRecord : l10n.sessionExpired,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 20),
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.phoneNumber,
                              hintText: l10n.phoneHint,
                              prefixIcon: const Icon(Icons.phone_iphone),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.go,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: l10n.password,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(l10n.loginSubmit),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!AppConfig.isSingleSacco) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l10n.notYourSacco),
                        TextButton(
                          onPressed: _busy ? null : () => context.read<Session>().forgetSacco(),
                          child: Text(l10n.changeSacco),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
