import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/money.dart';
import '../core/session.dart';
import '../l10n/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String errorText(BuildContext context, Object error) {
  final l10n = context.l10n;
  final e = toApiException(error);
  if (e.message == 'network') return l10n.networkError;
  return e.message.isNotEmpty ? e.message : l10n.genericError;
}

String formatDate(BuildContext context, DateTime? date) {
  if (date == null) return '—';
  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date.toLocal());
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ),
  );
}

/// Amount in the SACCO's own currency (KES/TZS - per-tenant config, never
/// hardcoded).
class AmountText extends StatelessWidget {
  final Decimal amount;
  final TextStyle? style;
  const AmountText(this.amount, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final currency = context.select<Session, String>((s) => s.currency);
    return Text(Money.withCurrency(amount, currency), style: style);
  }
}

String money(BuildContext context, Decimal amount) =>
    Money.withCurrency(amount, context.read<Session>().currency);

/// Loads [load] once, shows spinner / error-with-retry / content, and
/// supports pull-to-refresh.
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  const AsyncView({super.key, required this.load, required this.builder});

  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> reload() async {
    final next = widget.load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorRetry(message: errorText(context, snapshot.error!), onRetry: reload);
        }
        return RefreshIndicator(
          onRefresh: reload,
          child: widget.builder(context, snapshot.data as T, reload),
        );
      },
    );
  }
}

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleSmall)),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String text;
  const EmptyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

enum Tone { neutral, good, warn, bad }

class StatusChip extends StatelessWidget {
  final String label;
  final Tone tone;
  const StatusChip(this.label, {super.key, this.tone = Tone.neutral});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      Tone.good => (scheme.primaryContainer, scheme.onPrimaryContainer),
      Tone.warn => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      Tone.bad => (scheme.errorContainer, scheme.onErrorContainer),
      Tone.neutral => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// A label/value row for detail screens.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}


/// "Good morning, Mary" - the Home top bar.
String greeting(BuildContext context, String name) {
  final l10n = context.l10n;
  final hour = DateTime.now().hour;
  final first = name.trim().split(' ').first;
  if (hour < 12) return first.isEmpty ? l10n.greetMorningPlain : l10n.greetMorning(first);
  if (hour < 17) return first.isEmpty ? l10n.greetAfternoonPlain : l10n.greetAfternoon(first);
  return first.isEmpty ? l10n.greetEveningPlain : l10n.greetEvening(first);
}
