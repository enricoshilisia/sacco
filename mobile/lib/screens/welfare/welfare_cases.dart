import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/welfare.dart';
import '../../widgets/common.dart';
import '../../widgets/labels.dart';
import '../../core/profile_api.dart';
import '../../models/profile.dart';
import '../profile/profile_labels.dart';
import 'member_picker.dart';
import '../../widgets/inuka_app_bar.dart';

class WelfareCasesTab extends StatefulWidget {
  const WelfareCasesTab({super.key});

  @override
  State<WelfareCasesTab> createState() => _WelfareCasesTabState();
}

class _WelfareCasesTabState extends State<WelfareCasesTab> {
  String? _status = 'PENDING_APPROVAL';
  int _version = 0;

  Future<void> _open() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const OpenCaseScreen()));
    if (created == true) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final filters = <(String?, String)>[
      ('PENDING_APPROVAL', l10n.welfareStatusPENDING_APPROVAL),
      ('APPROVED', l10n.welfareFilterOpen),
      ('CLOSED', l10n.welfareStatusCLOSED),
      ('REJECTED', l10n.welfareStatusREJECTED),
      (null, l10n.all),
    ];
    return Scaffold(
      floatingActionButton: session.can('welfare.create_case')
          ? FloatingActionButton.extended(onPressed: _open, icon: const Icon(Icons.add), label: Text(l10n.welfareNewCase))
          : null,
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _status == f.$1,
                      onSelected: (_) => setState(() => _status = f.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<WelfareCase>>(
              key: ValueKey('$_status$_version'),
              load: () => session.api!.welfareCases(status: _status),
              builder: (context, cases, reload) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [
                  if (cases.isEmpty) EmptyNote(l10n.welfareNoCases),
                  for (final c in cases) ...[
                    _CaseCard(
                      welfareCase: c,
                      onTap: () async {
                        await Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => WelfareCaseScreen(caseId: c.id)));
                        reload();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final WelfareCase welfareCase;
  final VoidCallback onTap;
  const _CaseCard({required this.welfareCase, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = welfareCase;
    final (label, tone) = welfareCaseStatus(l10n, c.status);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(c.caseTypeName, style: theme.textTheme.titleSmall)),
                StatusChip(label, tone: tone),
              ]),
              const SizedBox(height: 4),
              Text(
                [c.beneficiary.fullName, c.beneficiary.memberNumber, if (c.affectedPerson.isNotEmpty) c.affectedPerson]
                    .join(' · '),
              ),
              const SizedBox(height: 4),
              Text(
                c.isPending
                    ? l10n.welfarePerMemberAmount(money(context, c.contributionPerMember))
                    : l10n.welfareCollectedOf(money(context, c.collected), money(context, c.totalLevied)),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OpenCaseScreen extends StatefulWidget {
  const OpenCaseScreen({super.key});

  @override
  State<OpenCaseScreen> createState() => _OpenCaseScreenState();
}

class _OpenCaseScreenState extends State<OpenCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  MemberBrief? _member;
  WelfareCaseType? _type;
  List<FamilyPerson>? _family;
  // '' = the member themself; otherwise a family member id.
  String? _affectedId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickMember() async {
    final picked = await pickMember(context);
    if (picked == null || !mounted) return;
    setState(() {
      _member = picked;
      _family = null;
      _affectedId = null;
    });
    try {
      final family = await context.read<Session>().api!.welfareFamily(picked.id);
      if (mounted) setState(() => _family = family);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    }
  }

  /// Who this case type can be opened for, from the member's approved register.
  List<(String, String)> _eligible() {
    final type = _type;
    final l10n = context.l10n;
    if (type == null || _member == null) return const [];
    final options = <(String, String)>[];
    if (type.covers.contains('SELF')) options.add(('', '${_member!.fullName} (${l10n.relSelf.toLowerCase()})'));
    for (final p in _family ?? const <FamilyPerson>[]) {
      if (!type.covers.contains(p.relationship)) continue;
      if (p.relationship == 'CHILD' && type.childMaxAge != null && (p.age ?? 999) > type.childMaxAge!) continue;
      options.add((p.id, '${p.fullName} (${relationshipLabel(l10n, p.relationship).toLowerCase()}'
          '${p.age != null ? ', ${l10n.ageYears(p.age!)}' : ''})'));
    }
    return options;
  }

  Future<void> _submit() async {
    if (_member == null) {
      setState(() => _error = context.l10n.welfarePickMember);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_affectedId == null) {
      setState(() => _error = context.l10n.welfarePickAffected);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().api!.openWelfareCase(
            caseTypeId: _type!.id,
            beneficiaryId: _member!.id,
            affectedFamilyMemberId: _affectedId!.isEmpty ? null : _affectedId,
            description: _description.text.trim(),
          );
      if (!mounted) return;
      showSnack(context, context.l10n.welfareCaseOpened);
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: InukaAppBar(title: l10n.welfareNewCase),
      body: AsyncView<List<WelfareCaseType>>(
        load: () => context.read<Session>().api!.welfareCaseTypes(activeOnly: true),
        builder: (context, types, reload) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_search_outlined),
                  title: Text(_member?.fullName ?? l10n.welfarePickMember),
                  subtitle: _member == null ? null : Text('${_member!.memberNumber} · ${_member!.phoneNumber}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickMember,
                ),
              ),
              const SizedBox(height: 16),
              if (types.isEmpty)
                EmptyNote(l10n.welfareNoRules)
              else
                DropdownButtonFormField<WelfareCaseType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.welfareCaseType),
                  items: [
                    for (final t in types)
                      DropdownMenuItem(value: t, child: Text('${t.name} · ${money(context, t.contributionPerMember)}')),
                  ],
                  validator: (v) => v == null ? l10n.required : null,
                  onChanged: (v) => setState(() {
                    _type = v;
                    _affectedId = null;
                  }),
                ),
              if (_type != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.welfareLevyPreview(money(context, _type!.contributionPerMember)),
                  style: theme.textTheme.bodySmall,
                ),
                if (_type!.description.isNotEmpty)
                  Text(_type!.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 16),
              if (_member != null && _type != null) ...[
                if (_family == null)
                  const LinearProgressIndicator()
                else if (_eligible().isEmpty)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l10n.welfareNobodyCovered),
                      subtitle: Text(l10n.welfareNobodyCoveredHelp),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('${_type!.id}${_member!.id}'),
                    initialValue: _affectedId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.welfareAffectedPerson),
                    items: [for (final o in _eligible()) DropdownMenuItem(value: o.$1, child: Text(o.$2))],
                    onChanged: (v) => setState(() => _affectedId = v),
                  ),
                const SizedBox(height: 6),
                Text(l10n.welfareRegisterOnlyHelp, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.welfareCaseDetails),
              ),
              const SizedBox(height: 8),
              Text(l10n.welfareNeedsApproval, style: theme.textTheme.bodySmall),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy || types.isEmpty ? null : _submit, child: Text(l10n.welfareOpenCase)),
            ],
          ),
        ),
      ),
    );
  }
}

class WelfareCaseScreen extends StatefulWidget {
  final String caseId;
  const WelfareCaseScreen({super.key, required this.caseId});

  @override
  State<WelfareCaseScreen> createState() => _WelfareCaseScreenState();
}

class _WelfareCaseScreenState extends State<WelfareCaseScreen> {
  final _view = GlobalKey<AsyncViewState<WelfareCase>>();
  bool _busy = false;

  Future<void> _act(Future<void> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showSnack(context, doneMessage);
      await _view.currentState?.reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askNotes({required String title, required bool required}) async {
    final controller = TextEditingController();
    final l10n = context.l10n;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: required ? l10n.welfareReason : l10n.welfareNotesOptional),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              if (required && controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: Text(l10n.done),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final api = session.api!;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.welfareCase),
      body: AsyncView<WelfareCase>(
        key: _view,
        load: () => api.welfareCase(widget.caseId),
        builder: (context, c, reload) {
          final theme = Theme.of(context);
          final (label, tone) = welfareCaseStatus(l10n, c.status);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(c.caseTypeName, style: theme.textTheme.titleMedium)),
                        StatusChip(label, tone: tone),
                      ]),
                      const SizedBox(height: 8),
                      InfoRow(l10n.welfareBeneficiary, '${c.beneficiary.fullName} (${c.beneficiary.memberNumber})'),
                      if (c.affectedPerson.isNotEmpty) InfoRow(l10n.welfareAffectedPerson, c.affectedPerson),
                      InfoRow(l10n.welfareContributionPerMember, money(context, c.contributionPerMember)),
                      InfoRow(l10n.welfareOpenedBy, '${c.createdBy} · ${formatDate(context, c.createdAt)}'),
                      if (c.decidedBy.isNotEmpty) InfoRow(l10n.welfareDecidedBy, c.decidedBy),
                      if (c.decisionNotes.isNotEmpty) InfoRow(l10n.decisionNotes, c.decisionNotes),
                      if (c.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(c.description),
                      ],
                    ],
                  ),
                ),
              ),
              if (!c.isPending && c.status != 'REJECTED') ...[
                SectionTitle(l10n.welfareCollection),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(children: [
                      if (c.leviedAt == null && c.isOpen)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(l10n.welfareLevyRunning)),
                          ]),
                        ),
                      InfoRow(l10n.welfareMembersLevied, '${c.membersLevied}'),
                      InfoRow(l10n.welfareTotalLevied, money(context, c.totalLevied)),
                      InfoRow(l10n.welfareCollected, money(context, c.collected)),
                      InfoRow(l10n.welfareOutstanding, money(context, c.outstanding)),
                      InfoRow(l10n.welfarePaidOut, money(context, c.paidOut)),
                      InfoRow(l10n.welfareAvailable, money(context, c.availableToPay)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (c.isPending && session.can('welfare.approve_case')) ...[
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final notes = await _askNotes(title: l10n.welfareApproveTitle, required: false);
                          if (notes == null) return;
                          await _act(() => api.approveWelfareCase(c.id, notes), l10n.welfareApproved);
                        },
                  icon: const Icon(Icons.check),
                  label: Text(l10n.approve),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final notes = await _askNotes(title: l10n.welfareRejectTitle, required: true);
                          if (notes == null) return;
                          await _act(() => api.rejectWelfareCase(c.id, notes), l10n.welfareRejected);
                        },
                  icon: const Icon(Icons.close),
                  label: Text(l10n.reject),
                ),
                const SizedBox(height: 4),
                Text(l10n.welfareApproveHelp, style: theme.textTheme.bodySmall),
              ],
              if (c.isOpen && session.can('welfare.record_payout')) ...[
                FilledButton.icon(
                  onPressed: _busy || c.availableToPay <= Decimal.zero
                      ? null
                      : () async {
                          final recorded = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            useSafeArea: true,
                            builder: (_) => ChangeNotifierProvider.value(
                              value: session,
                              child: _PayoutSheet(welfareCase: c),
                            ),
                          );
                          if (recorded == true) await reload();
                        },
                  icon: const Icon(Icons.outbox_outlined),
                  label: Text(l10n.welfareRecordPayout),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _act(() => api.closeWelfareCase(c.id), l10n.welfareCaseClosed),
                  child: Text(l10n.welfareCloseCase),
                ),
              ],
              if (c.payouts.isNotEmpty) ...[
                SectionTitle(l10n.welfarePayouts),
                Card(
                  child: Column(children: [
                    for (final p in c.payouts)
                      ListTile(
                        title: Text(money(context, p.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text([
                          paymentMethod(l10n, p.method),
                          if (p.paidTo.isNotEmpty) p.paidTo,
                          if (p.reference.isNotEmpty) p.reference,
                          if (p.recordedBy.isNotEmpty) p.recordedBy,
                        ].join(' · ')),
                        trailing: Text(formatDate(context, p.paidOn)),
                      ),
                  ]),
                ),
              ],
              if (c.membersLevied > 0) ...[
                SectionTitle(l10n.welfareWhoOwes),
                _Contributions(caseId: c.id),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Contributions extends StatefulWidget {
  final String caseId;
  const _Contributions({required this.caseId});

  @override
  State<_Contributions> createState() => _ContributionsState();
}

class _ContributionsState extends State<_Contributions> {
  bool _outstandingOnly = true;
  late Future<List<WelfareContribution>> _rows = _load();

  Future<List<WelfareContribution>> _load() =>
      context.read<Session>().api!.welfareCaseContributions(widget.caseId, outstandingOnly: _outstandingOnly);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.welfareOnlyOwing),
          value: _outstandingOnly,
          onChanged: (v) => setState(() {
            _outstandingOnly = v;
            _rows = _load();
          }),
        ),
        FutureBuilder<List<WelfareContribution>>(
          future: _rows,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) return EmptyNote(errorText(context, snap.error!));
            final rows = snap.data!;
            if (rows.isEmpty) return EmptyNote(l10n.welfareEveryonePaid);
            return Card(
              child: Column(children: [
                for (final r in rows)
                  ListTile(
                    dense: true,
                    title: Text(r.memberName),
                    subtitle: Text(r.memberNumber),
                    trailing: Text(
                      r.outstanding > Decimal.zero ? money(context, r.outstanding) : l10n.paid,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: r.outstanding > Decimal.zero ? Theme.of(context).colorScheme.error : null,
                      ),
                    ),
                  ),
              ]),
            );
          },
        ),
      ],
    );
  }
}

class _PayoutSheet extends StatefulWidget {
  final WelfareCase welfareCase;
  const _PayoutSheet({required this.welfareCase});

  @override
  State<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<_PayoutSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.welfareCase.availableToPay.toStringAsFixed(2));
  late final _paidTo = TextEditingController(text: widget.welfareCase.beneficiary.fullName);
  final _reference = TextEditingController();
  String _method = 'CASH';
  DateTime _paidOn = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _paidTo.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().api!.recordWelfarePayout(
            caseId: widget.welfareCase.id,
            amount: Money.parseUserInput(_amount.text)!,
            method: _method,
            paidOn: _paidOn,
            reference: _reference.text.trim(),
            paidTo: _paidTo.text.trim(),
          );
      if (!mounted) return;
      showSnack(context, context.l10n.welfarePayoutRecorded);
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
    final available = widget.welfareCase.availableToPay;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.welfareRecordPayout, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(l10n.welfarePayoutHelp(money(context, available)), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.amount, prefixText: '${context.read<Session>().currency} '),
                validator: (v) {
                  final value = Money.parseUserInput(v ?? '');
                  if (value == null) return l10n.amountInvalid;
                  if (value > available) return l10n.welfareMoreThanAvailable(money(context, available));
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'CASH', label: Text(l10n.methodCash)),
                  ButtonSegment(value: 'BANK', label: Text(l10n.methodBank)),
                  ButtonSegment(value: 'MOBILE_MONEY', label: Text(l10n.methodMobileMoney)),
                ],
                selected: {_method},
                onSelectionChanged: (s) => setState(() => _method = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _paidTo, decoration: InputDecoration(labelText: l10n.welfarePaidTo)),
              const SizedBox(height: 12),
              TextFormField(controller: _reference, decoration: InputDecoration(labelText: l10n.welfareReference)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(l10n.welfarePaidOn),
                subtitle: Text(formatDate(context, _paidOn)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _paidOn,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _paidOn = picked);
                },
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.welfareRecordPayout)),
            ],
          ),
        ),
      ),
    );
  }
}
