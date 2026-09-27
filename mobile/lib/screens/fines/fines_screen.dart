import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/fines_api.dart';
import '../../core/leader_api.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/fines.dart';
import '../../models/leader.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/glass.dart';
import '../../widgets/inuka_app_bar.dart';
import '../../widgets/labels.dart';
import 'bulk_charge_screen.dart';

/// The fines register: who owes what, charging a fine, receiving payment
/// and waiving. Each person only sees the buttons their role allows.
class FinesScreen extends StatefulWidget {
  const FinesScreen({super.key});

  @override
  State<FinesScreen> createState() => _FinesScreenState();
}

class _FinesScreenState extends State<FinesScreen> {
  final _view = GlobalKey<AsyncViewState<FinesSummary>>();
  String _filter = '';
  bool _owingOnly = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return AsyncView<FinesSummary>(
      key: _view,
      load: session.api!.finesSummary,
      builder: (context, summary, reload) {
        final theme = Theme.of(context);
        final rows = summary.members.where((r) {
          if (_owingOnly && r.outstanding <= Decimal.zero) return false;
          final q = _filter.toLowerCase();
          return q.isEmpty || r.memberName.toLowerCase().contains(q) || r.memberNumber.toLowerCase().contains(q);
        }).toList();
        return Scaffold(
          appBar: InukaAppBar(
            title: l10n.finesTitle,
            actions: [
              if (session.can('fines.charge'))
                IconButton(
                  tooltip: l10n.chargeFine,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  onPressed: () async {
                    final charged = await Navigator.of(context)
                        .push<bool>(MaterialPageRoute(builder: (_) => const ChargeFineScreen()));
                    if (charged == true) reload();
                  },
                ),
              if (session.can('fines.manage_rules'))
                IconButton(
                  tooltip: l10n.offenceTypes,
                  icon: const Icon(Icons.rule_rounded),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OffenceTypesScreen()));
                    reload();
                  },
                ),
            ],
          ),
          floatingActionButton: summary.canCharge
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final charged = await Navigator.of(context)
                        .push<bool>(MaterialPageRoute(builder: (_) => const BulkChargeScreen()));
                    if (charged == true) reload();
                  },
                  icon: const Icon(Icons.gavel_rounded),
                  label: Text(l10n.assignFines),
                )
              : null,
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
            GlassCard(
              child: Row(children: [
                Expanded(child: _Total(l10n.finesCharged, summary.charged)),
                Expanded(child: _Total(l10n.finesPaid, summary.paid, tone: InukaColors.green)),
                Expanded(child: _Total(l10n.finesOutstanding, summary.outstanding, tone: InukaColors.red)),
              ]),
            ),
            if (summary.waived > Decimal.zero)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l10n.finesWaivedTotal(money(context, summary.waived)), style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchMemberHint),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              FilterChip(
                label: Text(l10n.finesOwingOnly),
                selected: _owingOnly,
                onSelected: (v) => setState(() => _owingOnly = v),
              ),
              const Spacer(),
              Text(l10n.finesMembersCount(rows.length), style: theme.textTheme.bodySmall),
            ]),
            const SizedBox(height: 8),
            if (rows.isEmpty) EmptyNote(_owingOnly ? l10n.finesNobodyOwes : l10n.finesNone),
            for (final (i, r) in rows.indexed) ...[
              Appear(
                index: i,
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () async {
                    await Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => MemberFinesScreen(memberId: r.memberId)));
                    reload();
                  },
                  child: Row(children: [
                    CircleAvatar(
                      backgroundColor: r.outstanding > Decimal.zero
                          ? InukaColors.red.withValues(alpha: 0.15)
                          : InukaColors.green.withValues(alpha: 0.15),
                      child: Text('${r.count}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: r.outstanding > Decimal.zero ? InukaColors.red : InukaColors.green,
                          )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.memberName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(r.memberNumber, style: theme.textTheme.bodySmall),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      AmountText(r.outstanding),
                      if (r.paid > Decimal.zero)
                        Text(l10n.finesPaidOf(money(context, r.paid), money(context, r.charged)),
                            style: theme.textTheme.labelSmall),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ]),
        );
      },
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final Decimal amount;
  final Color? tone;
  const _Total(this.label, this.amount, {this.tone});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(money(context, amount),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: tone)),
      ]);
}

/// One member's fines, with the actions the person's role allows.
class MemberFinesScreen extends StatefulWidget {
  final String memberId;
  const MemberFinesScreen({super.key, required this.memberId});

  @override
  State<MemberFinesScreen> createState() => _MemberFinesScreenState();
}

class _MemberFinesScreenState extends State<MemberFinesScreen> {
  final _view = GlobalKey<AsyncViewState<MemberFines>>();

  Future<void> _pay(MemberFines data) async {
    final l10n = context.l10n;
    final result = await showDialog<(Decimal, String, String)>(
      context: context,
      builder: (_) => _PaymentDialog(owed: data.outstanding),
    );
    if (result == null || !mounted) return;
    if (await runAction(
        context,
        () => context.read<Session>().api!.recordFinePayment(
              memberId: data.memberId,
              amount: result.$1,
              method: result.$2,
              paidOn: DateTime.now(),
              idempotencyKey: const Uuid().v4(),
              reference: result.$3,
            ),
        done: l10n.finePaymentRecorded)) {
      _view.currentState?.reload();
    }
  }

  Future<void> _waive(FineItem fine) async {
    final l10n = context.l10n;
    final reason = await askText(context,
        title: l10n.waiveFine, label: l10n.waiveReason, required: true, message: l10n.waiveFineHelp);
    if (reason == null || !mounted) return;
    if (await runAction(context, () => context.read<Session>().api!.waiveFine(fine.id, reason),
        done: l10n.fineWaived)) {
      _view.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return AsyncView<MemberFines>(
      key: _view,
      load: () => session.api!.memberFines(widget.memberId),
      builder: (context, data, reload) => Scaffold(
        appBar: InukaAppBar(title: data.memberName, subtitle: data.memberNumber),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          GlassCard(
            child: Row(children: [
              Expanded(child: _Total(l10n.finesCharged, data.charged)),
              Expanded(child: _Total(l10n.finesPaid, data.paid, tone: InukaColors.green)),
              Expanded(child: _Total(l10n.finesOutstanding, data.outstanding, tone: InukaColors.red)),
            ]),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (session.can('fines.record_payment') && data.outstanding > Decimal.zero)
              ActionChip(
                avatar: const Icon(Icons.payments_outlined, size: 18),
                label: Text(l10n.recordFinePayment),
                onPressed: () => _pay(data),
              ),
            if (session.can('fines.charge'))
              ActionChip(
                avatar: const Icon(Icons.gavel_rounded, size: 18),
                label: Text(l10n.chargeFine),
                onPressed: () async {
                  final charged = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => ChargeFineScreen(memberId: data.memberId)));
                  if (charged == true) reload();
                },
              ),
          ]),
          const SizedBox(height: 8),
          FinesList(fines: data.fines, onWaive: session.can('fines.waive') ? _waive : null),
        ]),
      ),
    );
  }
}

/// The list of one person's fines - also used on a member's own screen.
class FinesList extends StatelessWidget {
  final List<FineItem> fines;
  final ValueChanged<FineItem>? onWaive;
  const FinesList({super.key, required this.fines, this.onWaive});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (fines.isEmpty) return EmptyNote(l10n.finesNone);
    return Column(children: [
      for (final f in fines)
        Card(
          child: ListTile(
            leading: Icon(
              f.isWaived ? Icons.do_not_disturb_on_outlined : (f.isOutstanding ? Icons.gavel_rounded : Icons.check_circle),
              color: f.isWaived ? theme.colorScheme.outline : (f.isOutstanding ? InukaColors.red : InukaColors.green),
            ),
            title: Text(f.offence, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([
              formatDate(context, f.incurredOn),
              if (f.notes.isNotEmpty) f.notes,
              if (f.meetingTitle.isNotEmpty) f.meetingTitle,
              if (f.isWaived) l10n.waivedBy(f.waivedByName, f.waivedReason),
              if (!f.isWaived && f.paid > Decimal.zero && f.isOutstanding)
                l10n.finesPaidOf(money(context, f.paid), money(context, f.amount)),
            ].join('\n')),
            isThreeLine: f.notes.isNotEmpty || f.isWaived,
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(context, f.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: f.isWaived ? TextDecoration.lineThrough : null,
                  )),
              StatusChip(f.statusLabel,
                  tone: f.isWaived ? Tone.neutral : (f.isOutstanding ? Tone.warn : Tone.good)),
            ]),
            onLongPress: onWaive != null && f.isOutstanding ? () => onWaive!(f) : null,
          ),
        ),
      if (onWaive != null && fines.any((f) => f.isOutstanding))
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l10n.waiveHint, style: theme.textTheme.bodySmall),
        ),
    ]);
  }
}

class _PaymentDialog extends StatefulWidget {
  final Decimal owed;
  const _PaymentDialog({required this.owed});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amount = TextEditingController(text: widget.owed.toString());
  final _reference = TextEditingController();
  String _method = 'CASH';

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.recordFinePayment),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l10n.finesOwedNow(money(context, widget.owed))),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.amount),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: InputDecoration(labelText: l10n.paymentMethodLabel),
          items: [
            for (final m in const ['CASH', 'BANK', 'MOBILE_MONEY'])
              DropdownMenuItem(value: m, child: Text(paymentMethod(l10n, m))),
          ],
          onChanged: (v) => setState(() => _method = v ?? _method),
        ),
        const SizedBox(height: 10),
        TextField(controller: _reference, decoration: InputDecoration(labelText: l10n.receiptReference)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () {
            final amount = Money.parseUserInput(_amount.text);
            if (amount == null || amount <= Decimal.zero) {
              showSnack(context, l10n.amountInvalid, error: true);
              return;
            }
            Navigator.pop(context, (amount, _method, _reference.text.trim()));
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Charge a fine: who, which rule, when, and (if different) how much.
class ChargeFineScreen extends StatefulWidget {
  final String? memberId;
  const ChargeFineScreen({super.key, this.memberId});

  @override
  State<ChargeFineScreen> createState() => _ChargeFineScreenState();
}

class _ChargeFineScreenState extends State<ChargeFineScreen> {
  MemberListItem? _member;
  OffenceTypeItem? _offence;
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  DateTime _on = DateTime.now();
  bool _busy = false;
  List<OffenceTypeItem>? _offences;
  List<MemberListItem>? _members;

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
        _amount.text = _offence?.amount.toString() ?? '';
      });
    }).catchError((_) {});
    api.searchMembers('').then((list) {
      if (!mounted) return;
      setState(() {
        _members = list;
        _member = widget.memberId == null ? null : list.where((m) => m.id == widget.memberId).firstOrNull;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_member == null || _offence == null) {
      showSnack(context, l10n.chooseMemberAndOffence, error: true);
      return;
    }
    final amount = Money.parseUserInput(_amount.text);
    if (amount == null || amount <= Decimal.zero) {
      showSnack(context, l10n.amountInvalid, error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => context.read<Session>().api!.chargeFine(
            memberId: _member!.id,
            offenceTypeId: _offence!.id,
            incurredOn: _on,
            amount: amount,
            notes: _notes.text.trim(),
          ),
      done: l10n.fineCharged,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.chargeFine),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<MemberListItem>(
          initialValue: _member,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.member),
          items: [
            for (final m in _members ?? const <MemberListItem>[])
              DropdownMenuItem(value: m, child: Text('${m.fullName} · ${m.memberNumber}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _member = v),
        ),
        const SizedBox(height: 12),
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
            _amount.text = v?.amount.toString() ?? _amount.text;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.amount, helperText: l10n.fineAmountHelp),
        ),
        DateField(label: l10n.fineDate, value: _on, lastDate: DateTime.now(), onChanged: (d) => setState(() => _on = d)),
        TextField(controller: _notes, decoration: InputDecoration(labelText: l10n.welfareNotesOptional)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.gavel_rounded),
          label: Text(l10n.chargeFine),
        ),
      ]),
    );
  }
}

/// The rules and their amounts.
class OffenceTypesScreen extends StatefulWidget {
  const OffenceTypesScreen({super.key});

  @override
  State<OffenceTypesScreen> createState() => _OffenceTypesScreenState();
}

class _OffenceTypesScreenState extends State<OffenceTypesScreen> {
  final _view = GlobalKey<AsyncViewState<List<OffenceTypeItem>>>();

  Future<void> _edit([OffenceTypeItem? offence]) async {
    final result = await showDialog<(String, Decimal, String, String, bool)>(
      context: context,
      builder: (_) => _OffenceDialog(offence: offence),
    );
    if (result == null || !mounted) return;
    if (await runAction(
        context,
        () => context.read<Session>().api!.saveOffenceType(
              id: offence?.id,
              name: result.$1,
              amount: result.$2,
              description: result.$3,
              fromAttendance: result.$4,
              isActive: result.$5,
            ),
        done: context.l10n.saved)) {
      _view.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.offenceTypes),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(l10n.newOffence),
      ),
      body: AsyncView<List<OffenceTypeItem>>(
        key: _view,
        load: context.read<Session>().api!.offenceTypes,
        builder: (context, offences, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Text(l10n.offenceTypesHelp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            for (final o in offences)
              Card(
                child: ListTile(
                  title: Text(o.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    if (o.description.isNotEmpty) o.description,
                    if (o.fromAttendance == 'ABSENT') l10n.offenceFromAbsent,
                    if (o.fromAttendance == 'LATE') l10n.offenceFromLate,
                    if (!o.isActive) l10n.offenceInactive,
                  ].join(' · ')),
                  trailing: Text(money(context, o.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () => _edit(o),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OffenceDialog extends StatefulWidget {
  final OffenceTypeItem? offence;
  const _OffenceDialog({this.offence});

  @override
  State<_OffenceDialog> createState() => _OffenceDialogState();
}

class _OffenceDialogState extends State<_OffenceDialog> {
  late final _name = TextEditingController(text: widget.offence?.name ?? '');
  late final _amount = TextEditingController(text: widget.offence?.amount.toString() ?? '');
  late final _description = TextEditingController(text: widget.offence?.description ?? '');
  late String _from = widget.offence?.fromAttendance ?? '';
  late bool _active = widget.offence?.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.offence == null ? l10n.newOffence : l10n.offenceTypes),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: l10n.offence)),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.amount),
          ),
          const SizedBox(height: 10),
          TextField(controller: _description, maxLines: 2, decoration: InputDecoration(labelText: l10n.fieldDescription)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _from,
            decoration: InputDecoration(labelText: l10n.offenceFromRegister),
            items: [
              DropdownMenuItem(value: '', child: Text(l10n.offenceFromNone)),
              DropdownMenuItem(value: 'ABSENT', child: Text(l10n.offenceFromAbsent)),
              DropdownMenuItem(value: 'LATE', child: Text(l10n.offenceFromLate)),
            ],
            onChanged: (v) => setState(() => _from = v ?? ''),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            title: Text(l10n.offenceActive),
            onChanged: (v) => setState(() => _active = v),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () {
            final amount = Money.parseUserInput(_amount.text);
            if (_name.text.trim().isEmpty || amount == null) {
              showSnack(context, l10n.amountInvalid, error: true);
              return;
            }
            Navigator.pop(context, (_name.text.trim(), amount, _description.text.trim(), _from, _active));
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Fines the register proposes for a meeting: absentees without apology
/// and latecomers. The committee unticks anyone who shouldn't be fined.
class MeetingFinesScreen extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;
  const MeetingFinesScreen({super.key, required this.meetingId, required this.meetingTitle});

  @override
  State<MeetingFinesScreen> createState() => _MeetingFinesScreenState();
}

class _MeetingFinesScreenState extends State<MeetingFinesScreen> {
  final _view = GlobalKey<AsyncViewState<List<FineProposal>>>();
  final _chosen = <String>{};
  bool _seeded = false;
  bool _busy = false;

  Future<void> _charge() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final count = await context.read<Session>().api!.chargeFinesFromMeeting(widget.meetingId, _chosen.toList());
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
    return AsyncView<List<FineProposal>>(
      key: _view,
      load: () => context.read<Session>().api!.meetingFineProposals(widget.meetingId),
      builder: (context, proposals, reload) {
        if (!_seeded) {
          _seeded = true;
          _chosen.addAll(proposals.where((p) => !p.alreadyCharged).map((p) => p.memberId));
        }
        final total = proposals
            .where((p) => _chosen.contains(p.memberId) && !p.alreadyCharged)
            .fold(Decimal.zero, (sum, p) => sum + p.amount);
        return Scaffold(
          appBar: InukaAppBar(title: l10n.chargeFinesFromRegister, subtitle: widget.meetingTitle),
          bottomNavigationBar: proposals.any((p) => !p.alreadyCharged)
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      onPressed: _busy || _chosen.isEmpty ? null : _charge,
                      icon: const Icon(Icons.gavel_rounded),
                      label: Text('${l10n.chargeFine} · ${money(context, total)}'),
                    ),
                  ),
                )
              : null,
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            Text(l10n.fineProposalsHelp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (proposals.isEmpty) EmptyNote(l10n.fineProposalsNone),
            for (final p in proposals)
              Card(
                child: CheckboxListTile(
                  value: p.alreadyCharged ? true : _chosen.contains(p.memberId),
                  onChanged: p.alreadyCharged
                      ? null
                      : (v) => setState(() => v == true ? _chosen.add(p.memberId) : _chosen.remove(p.memberId)),
                  title: Text(p.memberName),
                  subtitle: Text([
                    p.offence,
                    money(context, p.amount),
                    if (p.alreadyCharged) l10n.fineAlreadyCharged,
                  ].join(' · ')),
                ),
              ),
          ]),
        );
      },
    );
  }
}
