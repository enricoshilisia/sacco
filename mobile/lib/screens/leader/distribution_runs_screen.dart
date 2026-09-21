import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/leader_api.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/leader.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/inuka_app_bar.dart';

/// Dividend (on share capital) and interest (on deposits) runs: propose,
/// review, approve or reject, and pay out. The proposer can't approve their
/// own run - the backend refuses it.
class DistributionRunsScreen extends StatefulWidget {
  const DistributionRunsScreen({super.key});

  @override
  State<DistributionRunsScreen> createState() => _DistributionRunsScreenState();
}

class _DistributionRunsScreenState extends State<DistributionRunsScreen> {
  int _version = 0;

  Future<void> _propose() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _ProposeRunScreen()));
    if (created == true) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final canPropose = session.profile?.canAny(const ['distributions.run_dividend', 'distributions.run_interest']) ?? false;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.leaderDistributions),
      floatingActionButton: canPropose
          ? FloatingActionButton.extended(onPressed: _propose, icon: const Icon(Icons.add), label: Text(l10n.runPropose))
          : null,
      body: AsyncView<List<DistributionRunItem>>(
        key: ValueKey(_version),
        load: () => session.api!.distributionRuns(),
        builder: (context, runs, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (runs.isEmpty) EmptyNote(l10n.noRuns),
            for (final r in runs) ...[
              Card(
                child: ListTile(
                  title: Text(r.kind == 'DIVIDEND' ? l10n.kindDIVIDEND : '${l10n.kindINTEREST} · ${r.productName}'),
                  subtitle: Text([
                    '${formatDate(context, r.periodStart)} – ${formatDate(context, r.periodEnd)}',
                    '${Money.percent(r.rate)}%',
                    l10n.runMembers(r.memberCount),
                  ].join(' · ')),
                  trailing: Builder(builder: (context) {
                    final (label, tone) = runStatus(context, r.status);
                    return StatusChip(label, tone: tone);
                  }),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _RunScreen(runId: r.id)));
                    reload();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

(String, Tone) runStatus(BuildContext context, String code) {
  final l10n = context.l10n;
  return switch (code) {
    'PENDING_APPROVAL' => (l10n.welfareStatusPENDING_APPROVAL, Tone.warn),
    'APPROVED' => (l10n.welfareStatusAPPROVED, Tone.good),
    'REJECTED' => (l10n.welfareStatusREJECTED, Tone.bad),
    _ => (code, Tone.neutral),
  };
}

class _RunScreen extends StatelessWidget {
  final String runId;
  const _RunScreen({required this.runId});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final api = session.api!;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.leaderDistributions),
      body: AsyncView<DistributionRunItem>(
        load: () => api.distributionRun(runId),
        builder: (context, r, reload) {
          final theme = Theme.of(context);
          final (label, tone) = runStatus(context, r.status);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(r.kind == 'DIVIDEND' ? l10n.kindDIVIDEND : '${l10n.kindINTEREST} · ${r.productName}',
                            style: theme.textTheme.titleMedium),
                      ),
                      StatusChip(label, tone: tone),
                    ]),
                    const SizedBox(height: 8),
                    InfoRow(l10n.runPeriod, '${formatDate(context, r.periodStart)} – ${formatDate(context, r.periodEnd)}'),
                    InfoRow(l10n.runRate, '${Money.percent(r.rate)}%'),
                    InfoRow(l10n.runMembersLabel, '${r.memberCount}'),
                    InfoRow(l10n.gross, money(context, r.totalGross)),
                    InfoRow(l10n.wht, money(context, r.totalWht)),
                    InfoRow(l10n.net, money(context, r.totalNet)),
                    if (r.proposedBy.isNotEmpty) InfoRow(l10n.runProposedBy, r.proposedBy),
                    if (r.description.isNotEmpty) InfoRow(l10n.welfareCaseDetails, r.description),
                    if (r.rejectionReason.isNotEmpty) InfoRow(l10n.welfareReason, r.rejectionReason),
                  ]),
                ),
              ),
              if (!r.whtConfirmed)
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: ListTile(leading: const Icon(Icons.info_outline), title: Text(l10n.runWhtUnconfirmed)),
                ),
              const SizedBox(height: 16),
              if (r.isPending && session.can('distributions.approve_distribution')) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: Text(l10n.approve),
                  onPressed: () async {
                    final ok = await confirm(context,
                        title: l10n.runApproveTitle, body: l10n.runApproveBody(money(context, r.totalNet)), action: l10n.approve);
                    if (!ok || !context.mounted) return;
                    if (await runAction(context, () => api.approveDistributionRun(r.id), done: l10n.runApproved)) reload();
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: Text(l10n.reject),
                  onPressed: () async {
                    final reason = await askText(context, title: l10n.runRejectTitle, label: l10n.welfareReason, required: true);
                    if (reason == null || !context.mounted) return;
                    if (await runAction(context, () => api.rejectDistributionRun(r.id, reason), done: l10n.runRejected)) reload();
                  },
                ),
                const SizedBox(height: 4),
                Text(l10n.runApproveHelp, style: theme.textTheme.bodySmall),
              ],
              if (r.status == 'APPROVED' && session.can('distributions.disburse'))
                FilledButton.icon(
                  icon: const Icon(Icons.send_to_mobile),
                  label: Text(l10n.runPayout),
                  onPressed: () async {
                    final ok = await confirm(context,
                        title: l10n.runPayout, body: l10n.runPayoutBody(money(context, r.totalNet)), action: l10n.runPayout);
                    if (!ok || !context.mounted) return;
                    if (await runAction(context, () => api.payoutDistributionRun(r.id), done: l10n.runPayoutStarted)) reload();
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProposeRunScreen extends StatefulWidget {
  const _ProposeRunScreen();

  @override
  State<_ProposeRunScreen> createState() => _ProposeRunScreenState();
}

class _ProposeRunScreenState extends State<_ProposeRunScreen> {
  late String _kind = context.read<Session>().can('distributions.run_dividend') ? 'DIVIDEND' : 'INTEREST';
  final _rate = TextEditingController();
  final _description = TextEditingController();
  DateTime _start = DateTime(DateTime.now().year - 1, 1, 1);
  DateTime _end = DateTime(DateTime.now().year - 1, 12, 31);
  SavingsProduct? _product;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _rate.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    // Rate typed as a percentage ("10" = 10%) and sent as a fraction, exactly.
    final percent = Money.parseUserInput(_rate.text);
    if (_kind == 'DIVIDEND' && percent == null) return setState(() => _error = l10n.runRateRequired);
    if (_kind == 'INTEREST' && _product == null) return setState(() => _error = l10n.welfareRequiredProduct);
    final rate = percent == null ? null : Money.percentToFraction(percent);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<Session>().api!;
      if (_kind == 'DIVIDEND') {
        await api.proposeDividendRun(start: _start, end: _end, rate: rate!, description: _description.text.trim());
      } else {
        await api.proposeInterestRun(
            productId: _product!.id, start: _start, end: _end, rate: rate, description: _description.text.trim());
      }
      if (!mounted) return;
      showSnack(context, l10n.runProposed);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return Scaffold(
      appBar: InukaAppBar(title: l10n.runPropose),
      body: AsyncView<List<SavingsProduct>>(
        load: () => session.api!.savingsProducts(),
        builder: (context, products, reload) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: [
                if (session.can('distributions.run_dividend')) ButtonSegment(value: 'DIVIDEND', label: Text(l10n.kindDIVIDEND)),
                if (session.can('distributions.run_interest')) ButtonSegment(value: 'INTEREST', label: Text(l10n.kindINTEREST)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            if (_kind == 'INTEREST')
              DropdownButtonFormField<SavingsProduct>(
                initialValue: _product,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.savingsProduct),
                items: [for (final p in products) DropdownMenuItem(value: p, child: Text(p.name))],
                onChanged: (p) => setState(() => _product = p),
              ),
            DateField(label: l10n.reportFrom, value: _start, onChanged: (d) => setState(() => _start = d)),
            DateField(label: l10n.reportTo, value: _end, onChanged: (d) => setState(() => _end = d)),
            TextField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _kind == 'DIVIDEND' ? l10n.runRatePercent : l10n.runRatePercentOptional,
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _description, decoration: InputDecoration(labelText: l10n.runDescription)),
            const SizedBox(height: 8),
            Text(l10n.runProposeHelp, style: Theme.of(context).textTheme.bodySmall),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.runPropose)),
          ],
        ),
      ),
    );
  }
}
