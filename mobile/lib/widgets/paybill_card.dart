import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../theme.dart';
import 'common.dart';
import 'glass.dart';

/// How to pay: the SACCO's M-Pesa paybill and account number, with a tap to
/// copy. Shown until paying inside the app (STK push) is switched on.
class PaybillCard extends StatelessWidget {
  final bool compact;
  const PaybillCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profile = context.watch<Session>().profile;
    if (profile == null || !profile.hasPaybill) return const SizedBox.shrink();

    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            SizedBox(width: 92, child: Text(label, style: theme.textTheme.bodySmall)),
            Expanded(
              child: SelectableText(value,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: l10n.copy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) showSnack(context, l10n.copied);
              },
            ),
          ]),
        );

    return GlassCard(
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined, color: InukaColors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.howToPay, style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
        line(l10n.payBill, profile.paybillNumber),
        line(l10n.payAccount, profile.paybillAccount),
        if (profile.paymentInstructions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(profile.paymentInstructions, style: theme.textTheme.bodySmall),
        ],
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(l10n.payByHandHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ]),
    );
  }
}
