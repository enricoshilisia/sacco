import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/leader_api.dart';
import '../../core/session.dart';
import '../../models/leader.dart';
import '../../widgets/common.dart';
import '../home_shell.dart';
import '../welfare/welfare_screen.dart';
import 'distribution_runs_screen.dart';
import 'finance_screen.dart';
import 'loan_desk_screen.dart';
import 'members_screen.dart';
import 'reports_screen.dart';

/// Home for leaders and staff: what's waiting on them, and the modules
/// their role unlocks. Each module is also permission-checked server-side.
class LeaderHubScreen extends StatelessWidget {
  const LeaderHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final profile = session.profile;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    final modules = <(IconData, String, String, Widget)>[
      if (profile?.hasFinance ?? false) (Icons.account_balance_outlined, l10n.leaderFinance, l10n.leaderFinanceHelp, const FinanceScreen()),
      if (profile?.hasReports ?? false) (Icons.assessment_outlined, l10n.leaderReports, l10n.leaderReportsHelp, const ReportsScreen()),
      if (profile?.hasLoanDesk ?? false) (Icons.request_quote_outlined, l10n.leaderLoanDesk, l10n.leaderLoanDeskHelp, const LoanDeskScreen()),
      if (profile?.hasMembers ?? false) (Icons.groups_outlined, l10n.leaderMembers, l10n.leaderMembersHelp, const MembersScreen()),
      if (profile?.hasDistributions ?? false)
        (Icons.card_giftcard, l10n.leaderDistributions, l10n.leaderDistributionsHelp, const DistributionRunsScreen()),
      if (profile?.hasWelfareTools ?? false)
        (Icons.volunteer_activism_outlined, l10n.leaderWelfare, l10n.leaderWelfareHelp, const WelfareScreen(staffMode: true)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.leaderTitle),
            Text(session.sacco?.name ?? '', style: theme.textTheme.bodySmall),
          ],
        ),
        actions: const [ProfileButton()],
      ),
      body: AsyncView<List<LeaderTask>>(
        load: () => session.api!.myTasks(),
        builder: (context, tasks, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if ((profile?.roles ?? const []).isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in profile!.roles)
                  Chip(avatar: const Icon(Icons.badge_outlined, size: 16), label: Text(r)),
              ]),
            SectionTitle(l10n.leaderNeedsAttention),
            if (tasks.isEmpty)
              Card(
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
                  title: Text(l10n.leaderAllClear),
                ),
              ),
            for (final t in tasks) ...[
              Card(
                color: theme.colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.tertiary,
                    foregroundColor: theme.colorScheme.onTertiary,
                    child: Text('${t.count}'),
                  ),
                  title: Text(_taskLabel(context, t.key)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final screen = _taskScreen(t.key);
                    if (screen == null) return;
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
                    reload();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            SectionTitle(l10n.leaderModules),
            for (final m in modules) ...[
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: Icon(m.$1),
                  ),
                  title: Text(m.$2),
                  subtitle: Text(m.$3),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(m.$4),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  String _taskLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (key) {
      'loans_to_appraise' => l10n.taskLoansToAppraise,
      'loans_to_decide' => l10n.taskLoansToDecide,
      'loans_to_disburse' => l10n.taskLoansToDisburse,
      'distributions_to_approve' => l10n.taskDistributionsToApprove,
      'welfare_to_approve' => l10n.taskWelfareToApprove,
      _ => key,
    };
  }

  Widget? _taskScreen(String key) => switch (key) {
        'loans_to_appraise' => const LoanDeskScreen(initialQueue: LoanQueue.appraise),
        'loans_to_decide' => const LoanDeskScreen(initialQueue: LoanQueue.decide),
        'loans_to_disburse' => const LoanDeskScreen(initialQueue: LoanQueue.disburse),
        'distributions_to_approve' => const DistributionRunsScreen(),
        'welfare_to_approve' => const WelfareScreen(staffMode: true),
        _ => null,
      };
}

/// Opens Profile from an app bar when Profile isn't a bottom tab (a member
/// who is also a leader has too many tabs to fit it).
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = homeShellOf(context);
    if (shell == null || shell.profileIsTab) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: context.l10n.navProfile,
      onPressed: () => shell.openProfile(context),
    );
  }
}
