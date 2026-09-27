import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fines_api.dart';
import '../../core/leader_api.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/fines.dart';
import '../../models/leader.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/glass.dart';
import '../../widgets/inuka_app_bar.dart';

/// One sitting of the disciplinary committee: choose the offence, tick the
/// members, set each amount, then apply. Nothing is charged until Apply, and
/// if one line is wrong nothing is charged at all.
class BulkChargeScreen extends StatefulWidget {
  const BulkChargeScreen({super.key});

  @override
  State<BulkChargeScreen> createState() => _BulkChargeScreenState();
}

class _BulkChargeScreenState extends State<BulkChargeScreen> {
  List<OffenceTypeItem>? _offences;
  List<MemberListItem>? _members;
  OffenceTypeItem? _offence;
  DateTime _on = DateTime.now();
  final _notes = TextEditingController();
  final _filter = TextEditingController();
  final _amounts = <String, TextEditingController>{};
  final _chosen = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final api = context.read<Session>().api!;
    api.offenceTypes().then((list) {
      if (!mounted) return;
      final active = list.where((o) => o.isActive).toList();
      setState(() {
        _offences = active;
        _offence = active.isEmpty ? null : active.first;
      });
    }).catchError((_) {});
    api.searchMembers('').then((list) {
      if (!mounted) return;
      setState(() => _members = list);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _notes.dispose();
    _filter.dispose();
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _amountFor(String memberId) =>
      _amounts.putIfAbsent(memberId, () => TextEditingController(text: _offence?.amount.toString() ?? ''));

  Decimal get _total => _chosen.fold(Decimal.zero, (sum, id) {
        final value = Money.parseUserInput(_amounts[id]?.text ?? '');
        return sum + (value ?? Decimal.zero);
      });

  Future<void> _apply() async {
    final l10n = context.l10n;
    if (_offence == null || _chosen.isEmpty) {
      showSnack(context, l10n.chooseMemberAndOffence, error: true);
      return;
    }
    final entries = <Map<String, dynamic>>[];
    for (final id in _chosen) {
      final amount = Money.parseUserInput(_amounts[id]?.text ?? '');
      if (amount == null || amount <= Decimal.zero) {
        showSnack(context, l10n.finesFixAmounts, error: true);
        return;
      }
      entries.add({'member': id, 'amount': amount.toString()});
    }
    final ok = await confirm(context,
        title: l10n.applyFines,
        body: l10n.applyFinesBody(entries.length, money(context, _total)),
        action: l10n.applyFines);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final count = await context.read<Session>().api!.chargeFinesInBulk(
            offenceTypeId: _offence!.id,
            incurredOn: _on,
            entries: entries,
            notes: _notes.text.trim(),
          );
      if (!mounted) return;
      showSnack(context, l10n.finesChargedCount(count));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final query = _filter.text.toLowerCase();
    final members = (_members ?? const <MemberListItem>[])
        .where((m) => query.isEmpty || m.fullName.toLowerCase().contains(query) || m.memberNumber.contains(query))
        .toList();
    return Scaffold(
      appBar: InukaAppBar(title: l10n.assignFines),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _busy || _chosen.isEmpty ? null : _apply,
            icon: const Icon(Icons.gavel_rounded),
            label: Text('${l10n.applyFines} · ${_chosen.length} · ${money(context, _total)}'),
          ),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<OffenceTypeItem>(
              initialValue: _offence,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.offence),
              items: [
                for (final o in _offences ?? const <OffenceTypeItem>[])
                  DropdownMenuItem(value: o, child: Text('${o.name} · ${money(context, o.amount)}')),
              ],
              onChanged: (v) => setState(() {
                _offence = v;
                // Refill the amounts nobody has touched yet.
                for (final id in _chosen) {
                  _amounts[id]?.text = v?.amount.toString() ?? '';
                }
              }),
            ),
            DateField(label: l10n.fineDate, value: _on, lastDate: DateTime.now(), onChanged: (d) => setState(() => _on = d)),
            TextField(
              controller: _notes,
              decoration: InputDecoration(labelText: l10n.finesNotesLabel, hintText: l10n.finesNotesHint),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _filter,
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchMemberHint),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        Text(l10n.assignFinesHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        if (_members == null) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        for (final m in members)
          Card(
            child: Row(children: [
              Expanded(
                child: CheckboxListTile(
                  value: _chosen.contains(m.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _chosen.add(m.id);
                      _amountFor(m.id);
                    } else {
                      _chosen.remove(m.id);
                    }
                  }),
                  title: Text(m.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(m.memberNumber),
                ),
              ),
              if (_chosen.contains(m.id))
                SizedBox(
                  width: 96,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TextField(
                      controller: _amountFor(m.id),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.end,
                      decoration: InputDecoration(labelText: l10n.amount, isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}
