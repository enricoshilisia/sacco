import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'dashboard_screen.dart';
import 'leader/leader_hub.dart';
import 'loans_screen.dart';
import 'profile_screen.dart';
import 'savings_screen.dart';
import 'welfare/welfare_screen.dart';

enum AppTab { home, savings, loans, welfare, leader, profile }

/// Bottom-nav shell. Tabs depend on who is logged in: members get their
/// own money screens, staff get the modules their role grants, and a
/// person who is both gets both.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  AppTab _current = AppTab.home;

  // Bumped to force a tab to reload after an action elsewhere changed its
  // data (e.g. a payment completed from the dashboard's quick action).
  final Map<AppTab, int> _versions = {for (final t in AppTab.values) t: 0};

  /// Profile is a tab unless the bar is already full (a member who is also
  /// a leader); then it opens from the person icon on Home / Leader.
  bool profileIsTab = true;

  List<AppTab> _tabsFor(Session session) {
    final tabs = [
      if (session.isMember) ...[AppTab.home, AppTab.savings, AppTab.loans, AppTab.welfare],
      if (session.profile?.hasStaffTools ?? false) AppTab.leader,
    ];
    profileIsTab = tabs.length < 5;
    return [...tabs, if (profileIsTab) AppTab.profile];
  }

  void openProfile(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));

  void goTo(AppTab tab, {bool refresh = false}) => setState(() {
        _current = tab;
        if (refresh) _versions[tab] = _versions[tab]! + 1;
      });

  void refreshAll() => setState(() {
        for (final t in AppTab.values) {
          _versions[t] = _versions[t]! + 1;
        }
      });

  Widget _screen(AppTab tab) {
    final key = ValueKey('${tab.name}${_versions[tab]}');
    return switch (tab) {
      AppTab.home => DashboardScreen(key: key),
      AppTab.savings => SavingsScreen(key: key),
      AppTab.loans => LoansScreen(key: key),
      AppTab.welfare => WelfareScreen(key: key),
      AppTab.leader => LeaderHubScreen(key: key),
      AppTab.profile => ProfileScreen(key: key),
    };
  }

  NavigationDestination _destination(AppTab tab) {
    final l10n = context.l10n;
    return switch (tab) {
      AppTab.home => NavigationDestination(
          icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l10n.navHome),
      AppTab.savings => NavigationDestination(
          icon: const Icon(Icons.savings_outlined), selectedIcon: const Icon(Icons.savings), label: l10n.navSavings),
      AppTab.loans => NavigationDestination(
          icon: const Icon(Icons.request_quote_outlined),
          selectedIcon: const Icon(Icons.request_quote),
          label: l10n.navLoans),
      AppTab.welfare => NavigationDestination(
          icon: const Icon(Icons.volunteer_activism_outlined),
          selectedIcon: const Icon(Icons.volunteer_activism),
          label: l10n.navWelfare),
      AppTab.leader => NavigationDestination(
          icon: const Icon(Icons.workspace_premium_outlined),
          selectedIcon: const Icon(Icons.workspace_premium),
          label: l10n.navLeader),
      AppTab.profile => NavigationDestination(
          icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l10n.navProfile),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabsFor(context.watch<Session>());
    final index = tabs.contains(_current) ? tabs.indexOf(_current) : 0;
    return Scaffold(
      body: IndexedStack(index: index, children: [for (final t in tabs) _screen(t)]),
      bottomNavigationBar: GlassBar(
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => _current = tabs[i]),
          destinations: [for (final t in tabs) _destination(t)],
        ),
      ),
    );
  }
}

HomeShellState? homeShellOf(BuildContext context) => context.findAncestorStateOfType<HomeShellState>();
