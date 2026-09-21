import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/leader_api.dart';
import '../../core/session.dart';
import '../../models/leader.dart';
import '../../widgets/common.dart';
import 'distribution_runs_screen.dart';
import 'journal_screen.dart';
import 'report_view_screen.dart';
import 'reports_screen.dart';

/// Treasurer / accountant home: the group's financial position at a glance,
/// and the tools to run the books.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final api = session.api!;

    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaderFinance)),
      body: AsyncView<FinanceSummary>(
        load: api.financeSummary,
        builder: (context, s, reload) {
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                color: s.ledgerBalanced ? theme.colorScheme.primaryContainer : theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(s.ledgerBalanced ? Icons.verified_outlined : Icons.warning_amber),
                  title: Text(s.ledgerBalanced ? l10n.financeBalanced : l10n.financeUnbalanced),
                  subtitle: Text(l10n.financeTrialBalanceHint),
                  onTap: () => open(const ReportViewScreen(reportKey: 'trial_balance', params: 'as_of')),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.7,
                children: [
                  _Figure(l10n.financeCash, money(context, s.cash), Icons.payments_outlined),
                  _Figure(l10n.financeCollectionsToday, money(context, s.collectionsToday), Icons.phone_android),
                  _Figure(l10n.savingsTotal, money(context, s.savings), Icons.savings_outlined),
                  _Figure(l10n.shareCapital, money(context, s.shareCapital), Icons.pie_chart_outline),
                  _Figure(l10n.financeLoans, money(context, s.loansOutstanding), Icons.request_quote_outlined),
                  _Figure(l10n.financePar, '${s.par30}%', Icons.warning_amber_outlined,
                      danger: (Decimal.tryParse(s.par30) ?? Decimal.zero) > Decimal.fromInt(5)),
                  _Figure(l10n.financeWelfareFund, money(context, s.welfareFund), Icons.volunteer_activism_outlined),
                  _Figure(l10n.financeMembers, '${s.activeMembers}', Icons.groups_outlined),
                ],
              ),
              SectionTitle(l10n.financeThisYear),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    InfoRow(l10n.financeIncome, money(context, s.incomeYtd)),
                    InfoRow(l10n.financeExpenses, money(context, s.expensesYtd)),
                    const Divider(),
                    InfoRow(l10n.financeSurplus, money(context, s.surplusYtd)),
                  ]),
                ),
              ),
              SectionTitle(l10n.financeTools),
              Card(
                child: Column(children: [
                  _Tool(Icons.menu_book_outlined, l10n.financeJournal, l10n.financeJournalHelp, () => open(const JournalScreen())),
                  if (session.can('accounting.post_journal'))
                    _Tool(Icons.edit_note, l10n.financeNewEntry, l10n.financeNewEntryHelp,
                        () => open(const NewJournalEntryScreen())),
                  _Tool(Icons.account_tree_outlined, l10n.financeChart, l10n.financeChartHelp,
                      () => open(const ChartOfAccountsScreen())),
                  _Tool(Icons.assessment_outlined, l10n.leaderReports, l10n.leaderReportsHelp, () => open(const ReportsScreen())),
                  if (session.can('distributions.view'))
                    _Tool(Icons.card_giftcard, l10n.leaderDistributions, l10n.leaderDistributionsHelp,
                        () => open(const DistributionRunsScreen())),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool danger;
  const _Figure(this.label, this.value, this.icon, {this.danger = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: danger ? theme.colorScheme.error : theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: danger ? theme.colorScheme.error : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Tool(this.icon, this.title, this.subtitle, this.onTap);

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
