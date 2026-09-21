import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/labels.dart';
import 'home_shell.dart';
import 'pay_sheet.dart';
import '../widgets/inuka_app_bar.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    return Scaffold(
      appBar: InukaAppBar(title: context.l10n.savingsTitle),
      body: AsyncView<Statement>(
        load: () => session.api!.myStatement(),
        builder: (context, statement, reload) => _SavingsBody(statement: statement),
      ),
    );
  }
}

class _SavingsBody extends StatelessWidget {
  final Statement statement;
  const _SavingsBody({required this.statement});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final accounts = statement.savingsAccounts;

    Future<void> pay(PayPurpose purpose, {String? productId}) async {
      final paid = await showPaySheet(context, purpose: purpose, productId: productId);
      if (paid && context.mounted) homeShellOf(context)?.refreshAll();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Share capital and deposits are separate on purpose (CLAUDE.md
        // rule 5): shares are ownership and earn dividends; deposits are
        // withdrawable, earn interest, and back loans.
        _AccountCard(
          icon: Icons.pie_chart_outline,
          title: l10n.shareCapital,
          help: l10n.shareCapitalHelp,
          balance: statement.sharesBalance,
          actionLabel: l10n.actionContribute,
          onAction: () => pay(PayPurpose.shareContribution),
          historyTitle: l10n.contributions,
          history: statement.shareContributions,
        ),
        const SizedBox(height: 12),
        _AccountCard(
          icon: Icons.savings_outlined,
          title: l10n.savingsTotal,
          help: l10n.savingsHelp,
          balance: statement.savingsTotal,
          footnote: statement.savingsPledged > Decimal.zero
              ? l10n.pledgedLocked(money(context, statement.savingsPledged))
              : null,
          actionLabel: l10n.actionDeposit,
          onAction: () => pay(PayPurpose.savingsDeposit),
        ),
        SectionTitle(l10n.savingsAccounts),
        if (accounts.isEmpty) EmptyNote(l10n.noSavingsAccounts),
        for (final account in accounts) ...[
          _AccountCard(
            icon: Icons.account_balance_wallet_outlined,
            title: account.productName,
            help: account.accountNumber,
            // The backend's per-account `balance` is currently the member's
            // whole savings total (the ledger doesn't tag lines by product -
            // see savings.views.build_member_statement), so it's only a true
            // per-account figure when there's a single account.
            balance: accounts.length == 1 ? account.balance : null,
            actionLabel: l10n.actionDeposit,
            onAction: () => pay(PayPurpose.savingsDeposit, productId: account.productId),
            historyTitle: l10n.transactions,
            history: account.transactions,
          ),
          const SizedBox(height: 12),
        ],
        Text(
          l10n.withdrawalsAtBranch,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _AccountCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String help;
  final Decimal? balance;
  final String? footnote;
  final String actionLabel;
  final VoidCallback onAction;
  final String? historyTitle;
  final List<LedgerLine>? history;

  const _AccountCard({
    required this.icon,
    required this.title,
    required this.help,
    required this.balance,
    this.footnote,
    required this.actionLabel,
    required this.onAction,
    this.historyTitle,
    this.history,
  });

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final history = widget.history;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(widget.icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.title, style: theme.textTheme.titleSmall)),
            ]),
            if (widget.balance != null) ...[
              const SizedBox(height: 8),
              AmountText(widget.balance!, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 4),
            Text(widget.help, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (widget.footnote != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.tertiary),
                const SizedBox(width: 4),
                Expanded(child: Text(widget.footnote!, style: theme.textTheme.bodySmall)),
              ]),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: widget.onAction,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(widget.actionLabel),
                ),
                const Spacer(),
                if (history != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                    label: Text(widget.historyTitle ?? ''),
                  ),
              ],
            ),
            if (_expanded && history != null) ...[
              const Divider(),
              if (history.isEmpty) EmptyNote(l10n.noTransactions),
              for (final line in history)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    line.type == 'WITHDRAWAL' ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 18,
                    color: line.type == 'WITHDRAWAL' ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
                  title: Text(txLabel(l10n, line.type)),
                  subtitle: Text(formatDate(context, line.date)),
                  trailing: Text(
                    '${line.type == 'WITHDRAWAL' ? '−' : '+'}${money(context, line.amount)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
