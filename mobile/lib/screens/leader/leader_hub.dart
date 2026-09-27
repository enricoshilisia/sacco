import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/leader_api.dart';
import '../../core/session.dart';
import '../../models/leader.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/inuka_app_bar.dart';
import '../home_carousel.dart';
import '../home_shell.dart';
import 'tasks_list.dart';

/// Home for leaders and staff who aren't members: a greeting, their roles,
/// and what's waiting on them. Their modules are in the bottom menu.
class LeaderHubScreen extends StatelessWidget {
  const LeaderHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final profile = session.profile;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: InukaAppBar(title: greeting(context, profile?.firstName ?? '')),
      body: RefreshIndicator(
        onRefresh: () async => homeShellOf(context)?.refreshAll(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Appear(
              child: GlassCard(
                child: Row(children: [
                  const InukaLogo(size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.myRoles, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final r in profile?.roles ?? const <String>[])
                          Chip(label: Text(r), visualDensity: VisualDensity.compact),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Appear(index: 1, child: _HubCarousel()),
            const Appear(index: 2, child: LeaderTasksList()),
          ],
        ),
      ),
    );
  }
}


/// The same sliding cards as a member's Home, for a leader who isn't one.
class _HubCarousel extends StatefulWidget {
  const _HubCarousel();

  @override
  State<_HubCarousel> createState() => _HubCarouselState();
}

class _HubCarouselState extends State<_HubCarousel> {
  late final Future<List<LeaderTask>> _tasks = context.read<Session>().api!.myTasks();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<LeaderTask>>(
        future: _tasks,
        builder: (context, snap) => HomeCarousel(tasks: snap.data ?? const []),
      );
}
