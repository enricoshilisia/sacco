import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/labels.dart';

/// Dividends on share capital and interest on savings - two different
/// things (CLAUDE.md rule 5), shown with their withholding tax.
class DistributionsScreen extends StatelessWidget {
  const DistributionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dividendsTitle)),
      body: AsyncView<List<DistributionEntry>>(
        load: () => context.read<Session>().api!.myDistributions(),
        builder: (context, entries, reload) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (entries.isEmpty) EmptyNote(l10n.noDistributions),
            for (final e in entries) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(e.isInterest ? Icons.savings_outlined : Icons.pie_chart_outline,
                            size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.isInterest ? l10n.kindINTEREST : l10n.kindDIVIDEND,
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                        Builder(builder: (context) {
                          final (label, tone) = entryStatus(l10n, e.status);
                          return StatusChip(label, tone: tone);
                        }),
                      ]),
                      if (e.description.isNotEmpty || e.periodEnd != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            [if (e.description.isNotEmpty) e.description, formatDate(context, e.periodEnd)].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const Divider(height: 20),
                      InfoRow(l10n.gross, money(context, e.gross)),
                      InfoRow(l10n.wht, '− ${money(context, e.wht)}'),
                      InfoRow(l10n.net, money(context, e.net)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
