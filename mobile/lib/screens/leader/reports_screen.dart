import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/leader_api.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../models/leader.dart';
import '../../widgets/common.dart';
import 'report_view_screen.dart';
import '../../widgets/inuka_app_bar.dart';

(String, String, IconData) reportInfo(AppLocalizations l, String key) => switch (key) {
      'trial_balance' => (l.reportTrialBalance, l.reportTrialBalanceHelp, Icons.balance),
      'balance_sheet' => (l.reportBalanceSheet, l.reportBalanceSheetHelp, Icons.account_balance_outlined),
      'income_statement' => (l.reportIncomeStatement, l.reportIncomeStatementHelp, Icons.trending_up),
      'general_ledger' => (l.reportGeneralLedger, l.reportGeneralLedgerHelp, Icons.menu_book_outlined),
      'journal' => (l.reportJournal, l.reportJournalHelp, Icons.receipt_long_outlined),
      'member_balances' => (l.reportMemberBalances, l.reportMemberBalancesHelp, Icons.fact_check_outlined),
      'loan_portfolio' => (l.reportLoanPortfolio, l.reportLoanPortfolioHelp, Icons.request_quote_outlined),
      'collections' => (l.reportCollections, l.reportCollectionsHelp, Icons.phone_android),
      'distribution_register' => (l.reportDistributions, l.reportDistributionsHelp, Icons.card_giftcard),
      _ => (key, '', Icons.description_outlined),
    };

/// The reports this leader's role may open. Figures come straight from the
/// ledger; each can be exported as CSV for internal and external auditors.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.leaderReports),
      body: AsyncView<ReportCatalog>(
        load: () => context.read<Session>().api!.reportCatalog(),
        builder: (context, catalog, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(l10n.reportsIntro, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (catalog.reports.isEmpty) EmptyNote(l10n.reportsNone),
            for (final r in catalog.reports) ...[
              Builder(builder: (context) {
                final (title, help, icon) = reportInfo(l10n, r.key);
                return Card(
                  child: ListTile(
                    leading: Icon(icon),
                    title: Text(title),
                    subtitle: Text(help),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReportViewScreen(reportKey: r.key, params: r.params, canExport: catalog.canExport),
                    )),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
