import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/governance_api.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/governance.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/inuka_app_bar.dart';

/// The Secretary's view of member activity: who the monthly check flagged
/// (confirm to archive, or keep active), who's dormant (reactivate), and
/// the rules themselves.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: InukaAppBar(
          title: l10n.activityTitle,
          bottom: TabBar(tabs: [
            Tab(text: l10n.activityFlagged),
            Tab(text: l10n.activityDormant),
            Tab(text: l10n.activityRules),
          ]),
        ),
        body: const TabBarView(children: [_FlaggedTab(), _DormantTab(), _RulesTab()]),
      ),
    );
  }
}

class _FlaggedTab extends StatelessWidget {
  const _FlaggedTab();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final api = context.read<Session>().api!;
    return AsyncView<List<InactivityFlagItem>>(
      load: () => api.inactivityFlags(),
      builder: (context, flags, reload) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(l10n.activityFlaggedHelp, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (flags.isEmpty) EmptyNote(l10n.activityNoneFlagged),
          for (final f in flags)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(f.reason == 'CONTRIBUTIONS' ? Icons.savings_outlined : Icons.event_busy,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${f.memberName} · ${f.memberNumber}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 6),
                  Text(f.detail),
                  Text(formatDate(context, f.createdAt), style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final notes = await askText(context,
                              title: l10n.activityKeepActive, label: l10n.welfareReason, required: true,
                              message: l10n.activityKeepActiveHelp);
                          if (notes == null || !context.mounted) return;
                          if (await runAction(context, () => api.dismissFlag(f.id, notes), done: l10n.activityKept)) reload();
                        },
                        child: Text(l10n.activityKeepActive),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                        onPressed: () async {
                          final ok = await confirm(context,
                              title: l10n.activityArchive, body: l10n.activityArchiveBody(f.memberName), action: l10n.activityArchive);
                          if (!ok || !context.mounted) return;
                          if (await runAction(context, () => api.confirmFlag(f.id), done: l10n.activityArchived)) reload();
                        },
                        child: Text(l10n.activityArchive),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _DormantTab extends StatelessWidget {
  const _DormantTab();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final api = context.read<Session>().api!;
    return AsyncView<List<DormantMember>>(
      load: api.dormantMembers,
      builder: (context, members, reload) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(l10n.activityDormantHelp, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (members.isEmpty) EmptyNote(l10n.activityNoneDormant),
          for (final m in members)
            Card(
              child: ListTile(
                title: Text('${m.memberName} · ${m.memberNumber}'),
                subtitle: Text([formatDate(context, m.since), if (m.reason.isNotEmpty) m.reason].join(' · ')),
                trailing: TextButton(
                  onPressed: () async {
                    final reason = await askText(context, title: l10n.activityReactivate, label: l10n.welfareReason);
                    if (reason == null || !context.mounted) return;
                    if (await runAction(context, () => api.reactivateMember(m.memberId, reason), done: l10n.activityReactivated)) {
                      reload();
                    }
                  },
                  child: Text(l10n.activityReactivate),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RulesTab extends StatefulWidget {
  const _RulesTab();

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  ActivitySettings? _s;
  bool _contribution = true, _meetings = true, _busy = false;
  int _warnMonths = 2, _limitMonths = 3, _warnMeetings = 2, _limitMeetings = 3;
  final _minAmount = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minAmount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await context.read<Session>().api!.activitySettings();
      if (!mounted) return;
      setState(() {
        _s = s;
        _contribution = s.contributionRuleEnabled;
        _meetings = s.meetingRuleEnabled;
        _warnMonths = s.warnAfterMonths;
        _limitMonths = s.inactiveAfterMonths;
        _warnMeetings = s.warnAfterMeetings;
        _limitMeetings = s.inactiveAfterMeetings;
        _minAmount.text = s.minMonthlyContribution.toStringAsFixed(2);
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_warnMonths >= _limitMonths || _warnMeetings >= _limitMeetings) {
      return setState(() => _error = l10n.activityWarnBeforeLimit);
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await runAction(
      context,
      () => context.read<Session>().api!.saveActivitySettings(
            contributionRule: _contribution, warnMonths: _warnMonths, limitMonths: _limitMonths,
            minContribution: Money.parse(_minAmount.text.replaceAll(',', '')), meetingRule: _meetings,
            warnMeetings: _warnMeetings, limitMeetings: _limitMeetings,
          ),
      done: l10n.saved,
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _runNow() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final r = await context.read<Session>().api!.runActivityCheck();
      if (mounted) showSnack(context, l10n.activityCheckDone(r.flagged, r.warned));
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChanged) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(onPressed: value > 1 ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          IconButton(onPressed: value < 24 ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add_circle_outline)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_s == null) {
      return _error != null ? ErrorRetry(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator());
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.ruleContributions, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(l10n.ruleContributionsHelp),
              value: _contribution,
              onChanged: (v) => setState(() => _contribution = v),
            ),
            if (_contribution) ...[
              _stepper(l10n.ruleWarnAfterMonths, _warnMonths, (v) => setState(() => _warnMonths = v)),
              _stepper(l10n.ruleArchiveAfterMonths, _limitMonths, (v) => setState(() => _limitMonths = v)),
              TextField(
                controller: _minAmount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.ruleMinAmount,
                  prefixText: '${context.read<Session>().currency} ',
                  helperText: l10n.ruleMinAmountHelp,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.ruleMeetings, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(l10n.ruleMeetingsHelp),
              value: _meetings,
              onChanged: (v) => setState(() => _meetings = v),
            ),
            if (_meetings) ...[
              _stepper(l10n.ruleWarnAfterMeetings, _warnMeetings, (v) => setState(() => _warnMeetings = v)),
              _stepper(l10n.ruleArchiveAfterMeetings, _limitMeetings, (v) => setState(() => _limitMeetings = v)),
            ],
          ]),
        ),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.save)),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _busy ? null : _runNow,
        icon: const Icon(Icons.play_arrow),
        label: Text(l10n.activityRunNow),
      ),
      const SizedBox(height: 6),
      Text(
        _s!.lastRunAt == null ? l10n.activityNeverRun : l10n.activityLastRun(formatDate(context, _s!.lastRunAt)),
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(l10n.activityScheduleHelp, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
    ]);
  }
}
