import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/inuka_app_bar.dart';
import 'dashboard_screen.dart';
import 'leader/approvals_screen.dart';
import 'leader/distribution_runs_screen.dart';
import 'leader/finance_screen.dart';
import 'leader/leader_hub.dart';
import 'leader/loan_desk_screen.dart';
import 'leader/members_screen.dart';
import 'leader/reports_screen.dart';
import 'loans_screen.dart';
import 'profile_screen.dart';
import 'savings_screen.dart';
import 'welfare/welfare_screen.dart';

/// Every place the bottom menu (or the More page) can take someone.
enum AppTab {
  home, // member dashboard
  leaderHome, // home for leaders/staff who aren't members
  savings,
  loans,
  welfare, // member's own welfare
  finance,
  approvals,
  loanDesk,
  members,
  welfareAdmin,
  reports,
  distributions,
  profile,
  more,
}

/// Bottom-menu shell. The menu is built per person from what their roles
/// allow: a member gets their money screens; a Treasurer gets Finance and
/// Reports; a Teller gets the counter; someone with both gets both. At most
/// five items fit, so extra destinations move to a "More" page.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  AppTab _current = AppTab.home;
  List<AppTab> _bar = const [];
  List<AppTab> _more = const [];

  // Bumped to force a tab to reload after an action elsewhere changed its data.
  final Map<AppTab, int> _versions = {for (final t in AppTab.values) t: 0};

  bool get profileInBar => _bar.contains(AppTab.profile);

  void _layout(Session session) {
    final menu = buildMenu(isMember: session.isMember, profile: session.profile);
    _bar = menu.bar;
    _more = menu.more;
    if (!_bar.contains(_current)) _current = _bar.first;
  }

  /// Show a destination: switch to it if it's in the bar, otherwise open it.
  void goTo(AppTab tab, {bool refresh = false}) {
    if (_bar.contains(tab)) {
      setState(() {
        _current = tab;
        if (refresh) _versions[tab] = _versions[tab]! + 1;
      });
    } else {
      open(context, tab);
    }
  }

  void open(BuildContext context, AppTab tab) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screenFor(tab, pushed: true)));

  void refreshAll() => setState(() {
        for (final t in AppTab.values) {
          _versions[t] = _versions[t]! + 1;
        }
      });

  Widget screenFor(AppTab tab, {bool pushed = false}) {
    final key = pushed ? null : ValueKey('${tab.name}${_versions[tab]}');
    return switch (tab) {
      AppTab.home => DashboardScreen(key: key),
      AppTab.leaderHome => LeaderHubScreen(key: key),
      AppTab.savings => SavingsScreen(key: key),
      AppTab.loans => LoansScreen(key: key),
      AppTab.welfare => WelfareScreen(key: key),
      AppTab.finance => FinanceScreen(key: key),
      AppTab.approvals => ApprovalsScreen(key: key),
      AppTab.loanDesk => LoanDeskScreen(key: key),
      AppTab.members => MembersScreen(key: key),
      AppTab.welfareAdmin => WelfareScreen(key: key, staffMode: true),
      AppTab.reports => ReportsScreen(key: key),
      AppTab.distributions => DistributionRunsScreen(key: key),
      AppTab.profile => ProfileScreen(key: key),
      AppTab.more => _MoreScreen(key: key, items: _more),
    };
  }

  @override
  Widget build(BuildContext context) {
    _layout(context.watch<Session>());
    final index = _bar.indexOf(_current);
    return Scaffold(
      body: IndexedStack(index: index, children: [for (final t in _bar) screenFor(t)]),
      bottomNavigationBar: GlassNavBar(
        selectedIndex: index,
        onSelected: (i) => setState(() => _current = _bar[i]),
        items: [for (final t in _bar) navItem(AppLocalizations.of(context), t)],
      ),
    );
  }
}

const maxBarItems = 5;

/// What goes in someone's bottom menu, from what their roles allow, most
/// important first. A member gets their money screens; a Treasurer gets
/// Finance and Reports; a Teller gets the counter; someone with both gets
/// both. Anything past five items moves to the "More" page.
({List<AppTab> bar, List<AppTab> more}) buildMenu({required bool isMember, TenantProfile? profile}) {
  final p = profile;
  final staff = <AppTab>[
    if (p?.hasFinance ?? false) AppTab.finance,
    if (p?.hasApprovals ?? false) AppTab.approvals,
    if (p?.hasLoanDesk ?? false) AppTab.loanDesk,
    if (p?.hasMembers ?? false) AppTab.members,
    if (p?.hasWelfareTools ?? false) AppTab.welfareAdmin,
    if (p?.hasReports ?? false) AppTab.reports,
    if (p?.hasDistributions ?? false) AppTab.distributions,
  ];
  final List<AppTab> all;
  if (!isMember) {
    all = [AppTab.leaderHome, ...staff, AppTab.profile];
  } else if (staff.isEmpty) {
    all = [AppTab.home, AppTab.savings, AppTab.loans, AppTab.welfare, AppTab.profile];
  } else {
    // A leader who is also a member: their main leader tool sits right after
    // Home, then their own money screens, then everything else.
    all = [AppTab.home, staff.first, AppTab.savings, AppTab.loans, AppTab.welfare, ...staff.skip(1), AppTab.profile];
  }
  if (all.length <= maxBarItems) return (bar: all, more: const <AppTab>[]);
  return (bar: [...all.take(maxBarItems - 1), AppTab.more], more: all.skip(maxBarItems - 1).toList());
}

HomeShellState? homeShellOf(BuildContext context) => context.findAncestorStateOfType<HomeShellState>();

GlassNavItem navItem(AppLocalizations l, AppTab tab) => switch (tab) {
      AppTab.home || AppTab.leaderHome => GlassNavItem(Icons.home_outlined, Icons.home_rounded, l.navHome),
      AppTab.savings => GlassNavItem(Icons.savings_outlined, Icons.savings, l.navSavings),
      AppTab.loans => GlassNavItem(Icons.request_quote_outlined, Icons.request_quote, l.navLoans),
      AppTab.welfare => GlassNavItem(Icons.volunteer_activism_outlined, Icons.volunteer_activism, l.navWelfare),
      AppTab.finance => GlassNavItem(Icons.account_balance_outlined, Icons.account_balance, l.navFinance),
      AppTab.approvals => GlassNavItem(Icons.task_alt_outlined, Icons.task_alt, l.navApprovals),
      AppTab.loanDesk => GlassNavItem(Icons.fact_check_outlined, Icons.fact_check, l.navLoanDesk),
      AppTab.members => GlassNavItem(Icons.groups_outlined, Icons.groups, l.navMembers),
      AppTab.welfareAdmin => GlassNavItem(Icons.volunteer_activism_outlined, Icons.volunteer_activism, l.navWelfare),
      AppTab.reports => GlassNavItem(Icons.assessment_outlined, Icons.assessment, l.navReports),
      AppTab.distributions => GlassNavItem(Icons.card_giftcard_outlined, Icons.card_giftcard, l.navDividends),
      AppTab.profile => GlassNavItem(Icons.person_outline, Icons.person, l.navProfile),
      AppTab.more => GlassNavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, l.navMore),
    };

(String, String) _moreText(AppLocalizations l, AppTab tab) => switch (tab) {
      AppTab.savings => (l.navSavings, l.savingsHelp),
      AppTab.loans => (l.navLoans, l.myLoans),
      AppTab.welfare => (l.welfareMine, l.welfareBalanceHelp),
      AppTab.finance => (l.leaderFinance, l.leaderFinanceHelp),
      AppTab.approvals => (l.approvalsTitle, l.approvalsHelp),
      AppTab.loanDesk => (l.leaderLoanDesk, l.leaderLoanDeskHelp),
      AppTab.members => (l.leaderMembers, l.leaderMembersHelp),
      AppTab.welfareAdmin => (l.leaderWelfare, l.leaderWelfareHelp),
      AppTab.reports => (l.leaderReports, l.leaderReportsHelp),
      AppTab.distributions => (l.leaderDistributions, l.leaderDistributionsHelp),
      AppTab.profile => (l.profileTitle, l.moreProfileHelp),
      _ => ('', ''),
    };

/// The rest of this person's destinations, as a grid of glass tiles.
class _MoreScreen extends StatelessWidget {
  final List<AppTab> items;
  const _MoreScreen({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: InukaAppBar(title: l10n.navMore),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final tab = items[i];
          final item = navItem(l10n, tab);
          final (title, subtitle) = _moreText(l10n, tab);
          return Appear(
            index: i,
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              onTap: () => homeShellOf(context)?.open(context, tab),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(gradient: InukaColors.sunrise, borderRadius: BorderRadius.circular(14)),
                    child: Icon(item.selectedIcon, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
