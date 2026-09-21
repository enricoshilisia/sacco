import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/leader_api.dart';
import '../../core/session.dart';
import '../../models/leader.dart';
import '../../widgets/common.dart';
import '../welfare/welfare_screen.dart';
import 'activity_screen.dart';
import 'admission_screens.dart';
import 'approvals_screen.dart';
import 'distribution_runs_screen.dart';
import 'loan_desk_screen.dart';

/// "Needs your attention": counts of what's waiting on this leader
/// (loans to appraise/decide/disburse, runs and welfare cases to approve).
/// Used on the leader Home and on a leader-member's dashboard.
class LeaderTasksList extends StatefulWidget {
  /// Show a friendly "all clear" card when nothing is waiting (leader home);
  /// the member dashboard hides the section entirely instead.
  final bool showAllClear;
  const LeaderTasksList({super.key, this.showAllClear = true});

  @override
  State<LeaderTasksList> createState() => _LeaderTasksListState();
}

class _LeaderTasksListState extends State<LeaderTasksList> {
  late Future<List<LeaderTask>> _tasks = _load();

  Future<List<LeaderTask>> _load() => context.read<Session>().api!.myTasks();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return FutureBuilder<List<LeaderTask>>(
      future: _tasks,
      builder: (context, snap) {
        final tasks = snap.data ?? const <LeaderTask>[];
        if (snap.connectionState != ConnectionState.done || snap.hasError) return const SizedBox.shrink();
        if (tasks.isEmpty && !widget.showAllClear) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(l10n.leaderNeedsAttention),
            if (tasks.isEmpty)
              Card(
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline, color: theme.colorScheme.tertiary),
                  title: Text(l10n.leaderAllClear),
                ),
              ),
            for (final t in tasks) ...[
              Card(
                color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.85),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    child: Text('${t.count}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  title: Text(taskLabel(context, t.key)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final screen = taskScreen(t.key);
                    if (screen == null) return;
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
                    if (mounted) setState(() => _tasks = _load());
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

String taskLabel(BuildContext context, String key) {
  final l10n = context.l10n;
  return switch (key) {
    'loans_to_appraise' => l10n.taskLoansToAppraise,
    'loans_to_decide' => l10n.taskLoansToDecide,
    'loans_to_disburse' => l10n.taskLoansToDisburse,
    'distributions_to_approve' => l10n.taskDistributionsToApprove,
    'welfare_to_approve' => l10n.taskWelfareToApprove,
    'profile_changes_to_approve' => l10n.taskProfileChanges,
    'members_to_archive' => l10n.taskMembersToArchive,
    'applications_to_approve' => l10n.taskApplicationsToApprove,
    _ => key,
  };
}

Widget? taskScreen(String key) => switch (key) {
      'loans_to_appraise' => const LoanDeskScreen(initialQueue: LoanQueue.appraise),
      'loans_to_decide' => const LoanDeskScreen(initialQueue: LoanQueue.decide),
      'loans_to_disburse' => const LoanDeskScreen(initialQueue: LoanQueue.disburse),
      'distributions_to_approve' => const DistributionRunsScreen(),
      'welfare_to_approve' => const WelfareScreen(staffMode: true),
      'profile_changes_to_approve' => const ApprovalsScreen(),
      'members_to_archive' => const ActivityScreen(),
      'applications_to_approve' => const ApplicationsView(),
      _ => null,
    };
