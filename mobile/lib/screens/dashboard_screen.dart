import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/money.dart';
import '../core/session.dart';
import '../models/models.dart';
import '../models/welfare.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/labels.dart';
import 'apply_loan_screen.dart';
import 'home_shell.dart';
import 'leader/tasks_list.dart';
import 'pay_sheet.dart';
import 'profile/my_profile_screen.dart';
import '../widgets/inuka_app_bar.dart';

class _DashboardData {
  final Statement statement;
  final List<Loan> loans;
  final List<LoanGuarantor> pendingGuarantees;
  final List<Collection> recentCollections;
  final WelfareSummary? welfare;
  _DashboardData(this.statement, this.loans, this.pendingGuarantees, this.recentCollections, this.welfare);
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<_DashboardData> _load(Session session) async {
    final api = session.api!;
    final results = await Future.wait([
      api.myStatement(),
      api.myLoans(),
      api.myGuaranteeRequests(),
      api.myCollections(),
      // Welfare is optional on the dashboard - a failure here shouldn't
      // blank the whole screen.
      api.myWelfare().then<MemberWelfare?>((w) => w, onError: (_) => null),
    ]);
    return _DashboardData(
      results[0] as Statement,
      results[1] as List<Loan>,
      (results[2] as List<LoanGuarantor>).where((g) => g.status == 'PENDING').toList(),
      (results[3] as List<Collection>).take(3).toList(),
      (results[4] as MemberWelfare?)?.summary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final l10n = context.l10n;
    final member = session.member;
    return Scaffold(
      appBar: InukaAppBar(
        title: l10n.navHome,
        subtitle: [
          l10n.welcome(member?.firstName ?? session.profile?.firstName ?? ''),
          if (member != null) l10n.memberNumber(member.memberNumber),
        ].join(' · '),
      ),
      body: AsyncView<_DashboardData>(
        load: () => _load(session),
        builder: (context, data, reload) => _DashboardBody(data: data, reload: reload),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final _DashboardData data;
  final Future<void> Function() reload;
  const _DashboardBody({required this.data, required this.reload});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final savingsTotal = data.statement.savingsTotal;
    final activeLoans = data.loans.where((l) => l.isActive).toList();
    final loanOutstanding = Money.sum(activeLoans.map((l) => l.outstandingBalance));
    final overdue = activeLoans.where((l) => l.isOverdue).toList();

    ScheduleRow? next;
    for (final loan in activeLoans) {
      final row = loan.nextInstallment;
      if (row?.dueDate != null && (next == null || row!.dueDate!.isBefore(next.dueDate!))) next = row;
    }

    Future<void> pay(PayPurpose purpose) async {
      final paid = await showPaySheet(context, purpose: purpose);
      if (paid && context.mounted) homeShellOf(context)?.refreshAll();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Until the member's details and family register are approved, nudge them.
        if (context.read<Session>().member != null && !context.read<Session>().member!.profileApproved)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyProfileScreen()));
                if (context.mounted) await context.read<Session>().reloadMember();
              },
              tint: const LinearGradient(colors: [Color(0xEEE2342B), Color(0xE6F28A1E)]),
              child: Row(children: [
                const Icon(Icons.assignment_ind_outlined, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.completeProfileTitle,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    Text(l10n.completeProfileBody, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),
        // Leaders who are also members see what's waiting on them here.
        if (context.read<Session>().profile?.hasStaffTools ?? false) const LeaderTasksList(showAllClear: false),
        if (data.pendingGuarantees.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Icon(Icons.handshake_outlined, color: theme.colorScheme.onTertiaryContainer),
                title: Text(
                  l10n.guaranteeRequestsBanner(data.pendingGuarantees.length),
                  style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
                ),
                trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onTertiaryContainer),
                onTap: () => homeShellOf(context)?.goTo(AppTab.loans, refresh: true),
              ),
            ),
          ),
        if (data.welfare != null && data.welfare!.owed > Decimal.zero)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Icon(Icons.volunteer_activism_outlined, color: theme.colorScheme.onErrorContainer),
                title: Text(
                  l10n.welfareOwedBanner(money(context, data.welfare!.owed)),
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onErrorContainer),
                onTap: () => homeShellOf(context)?.goTo(AppTab.welfare, refresh: true),
              ),
            ),
          ),
        Appear(
          child: _BalanceCard(
            icon: Icons.pie_chart_outline,
            title: l10n.shareCapital,
            help: l10n.shareCapitalHelp,
            amount: data.statement.sharesBalance,
            hero: true,
            onTap: () => homeShellOf(context)?.goTo(AppTab.savings),
          ),
        ),
        const SizedBox(height: 12),
        Appear(
          index: 1,
          child: _BalanceCard(
            icon: Icons.savings_outlined,
            title: l10n.savingsTotal,
            help: l10n.savingsHelp,
            amount: savingsTotal,
            onTap: () => homeShellOf(context)?.goTo(AppTab.savings),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => homeShellOf(context)?.goTo(AppTab.loans),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.request_quote_outlined, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.loanOutstanding, style: theme.textTheme.titleSmall),
                  ]),
                  const SizedBox(height: 8),
                  if (activeLoans.isEmpty)
                    Text(l10n.noActiveLoans, style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                  else ...[
                    AmountText(loanOutstanding, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                    if (next != null) ...[
                      const SizedBox(height: 4),
                      Text(l10n.nextPayment(
                        money(context, next.totalDue - next.paid),
                        formatDate(context, next.dueDate),
                      )),
                    ],
                    for (final loan in overdue) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.overdue(loan.daysOverdue, money(context, loan.amountOverdue)),
                        style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        SectionTitle(l10n.quickActions),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.85,
          children: [
            _QuickAction(Icons.add_card, l10n.actionDeposit, () => pay(PayPurpose.savingsDeposit)),
            _QuickAction(Icons.pie_chart_outline, l10n.actionContribute, () => pay(PayPurpose.shareContribution)),
            _QuickAction(Icons.request_quote_outlined, l10n.actionApply, () async {
              final created = await Navigator.of(context)
                  .push<bool>(MaterialPageRoute(builder: (_) => const ApplyLoanScreen()));
              if (created == true && context.mounted) homeShellOf(context)?.goTo(AppTab.loans, refresh: true);
            }),
            _QuickAction(Icons.volunteer_activism_outlined, l10n.welfarePay, () async {
              final w = data.welfare;
              final paid = await showPaySheet(
                context,
                purpose: PayPurpose.welfare,
                initialAmount: w == null ? null : w.owed + w.yearlyRemaining,
              );
              if (paid && context.mounted) homeShellOf(context)?.refreshAll();
            }),
          ],
        ),
        if (data.recentCollections.isNotEmpty) ...[
          SectionTitle(l10n.recentPayments),
          Card(
            child: Column(
              children: [
                for (final c in data.recentCollections)
                  ListTile(
                    title: Text(c.productName ?? purposeLabel(l10n, c.purpose)),
                    subtitle: Text(formatDate(context, c.createdAt)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AmountText(c.amount, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Builder(builder: (context) {
                          final (label, tone) = collectionStatus(l10n, c.status);
                          return StatusChip(label, tone: tone);
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String help;
  final Decimal amount;
  final VoidCallback onTap;
  final bool hero;
  const _BalanceCard({
    required this.icon,
    required this.title,
    required this.help,
    required this.amount,
    required this.onTap,
    this.hero = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = hero ? Colors.white : theme.colorScheme.onSurface;
    final muted = hero ? Colors.white.withValues(alpha: 0.85) : theme.colorScheme.onSurfaceVariant;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      tint: hero
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                InukaColors.sunrise.colors.first.withValues(alpha: 0.92),
                InukaColors.sunrise.colors.last.withValues(alpha: 0.88),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: hero ? Colors.white.withValues(alpha: 0.22) : theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: hero ? Colors.white : theme.colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Text(title, style: theme.textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          AmountText(amount, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 4),
          Text(help, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primaryContainer,
            child: Icon(icon, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
