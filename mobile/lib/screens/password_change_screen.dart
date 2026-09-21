import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

/// Shown after signing in with a temporary password (a new member's first
/// sign-in, or after an admin reset): choose your own before going on.
class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<Session>();
    try {
      await session.api!.changePassword(_current.text.trim(), _next.text);
      if (!mounted) return;
      showSnack(context, context.l10n.passwordChanged);
      await session.passwordChanged();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: InukaLogo(size: 64)),
                    const SizedBox(height: 16),
                    Text(l10n.tempPasswordTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(l10n.tempPasswordHelp, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _current,
                      obscureText: true,
                      decoration: InputDecoration(labelText: l10n.tempPasswordCurrent),
                      validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _next,
                      obscureText: true,
                      decoration: InputDecoration(labelText: l10n.newPassword),
                      validator: (v) => (v ?? '').length < 8 ? l10n.passwordTooShort : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: true,
                      decoration: InputDecoration(labelText: l10n.confirmPassword),
                      validator: (v) => v != _next.text ? l10n.passwordMismatch : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.changePassword)),
                    TextButton(
                      onPressed: _busy ? null : () => context.read<Session>().logout(),
                      child: Text(l10n.logout),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
