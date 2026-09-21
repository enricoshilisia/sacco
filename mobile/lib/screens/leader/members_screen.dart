import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/leader_api.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/leader.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/labels.dart';
import '../../models/welfare.dart';
import '../welfare/welfare_counter.dart';
import 'loan_desk_screen.dart';

/// Member directory for staff (members.view): search, open a member, and
/// do counter work their role allows.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  late Future<List<MemberListItem>> _results = _search('');

  Future<List<MemberListItem>> _search(String q) => context.read<Session>().api!.searchMembers(q);

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaderMembers)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _query,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchMemberHint),
            onChanged: (text) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _results = _search(text)));
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<MemberListItem>>(
            future: _results,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) {
                return ErrorRetry(
                    message: errorText(context, snap.error!), onRetry: () => setState(() => _results = _search(_query.text)));
              }
              final members = snap.data!;
              if (members.isEmpty) return Center(child: EmptyNote(l10n.noMembersFound));
              return ListView.separated(
                itemCount: members.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final m = members[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text(m.fullName.isEmpty ? '?' : m.fullName[0].toUpperCase())),
                    title: Text(m.fullName),
                    subtitle: Text('${m.memberNumber} · ${m.phoneNumber}'),
                    trailing: m.isKycVerified ? null : StatusChip(l10n.kycPending, tone: Tone.warn),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: m.id))),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _MemberData {
  final Member member;
  final Statement? statement;
  final List<Loan>? loans;
  _MemberData(this.member, this.statement, this.loans);
}

class MemberDetailScreen extends StatefulWidget {
  final String memberId;
  const MemberDetailScreen({super.key, required this.memberId});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final _view = GlobalKey<AsyncViewState<_MemberData>>();

  Future<_MemberData> _load() async {
    final session = context.read<Session>();
    final api = session.api!;
    final results = await Future.wait([
      api.member(widget.memberId),
      session.can('savings.view') ? api.memberStatement(widget.memberId) : Future.value(null),
      session.can('loans.view') ? api.memberLoans(widget.memberId) : Future.value(null),
    ]);
    return _MemberData(results[0] as Member, results[1] as Statement?, results[2] as List<Loan>?);
  }

  Future<void> _counter(_CounterAction action, _MemberData data) async {
    final session = context.read<Session>();
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: session,
        child: _CounterSheet(action: action, member: data.member, statement: data.statement),
      ),
    );
    if (done == true) _view.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaderMember)),
      body: AsyncView<_MemberData>(
        key: _view,
        load: _load,
        builder: (context, data, reload) {
          final m = data.member;
          final theme = Theme.of(context);
          final actions = <(IconData, String, VoidCallback)>[
            if (session.can('savings.deposit')) ...[
              (Icons.add_card, l10n.actionDeposit, () => _counter(_CounterAction.deposit, data)),
              (Icons.pie_chart_outline, l10n.actionContribute, () => _counter(_CounterAction.shares, data)),
            ],
            if (session.can('savings.withdraw') && (data.statement?.savingsAccounts.isNotEmpty ?? false))
              (Icons.outbox_outlined, l10n.counterWithdraw, () => _counter(_CounterAction.withdraw, data)),
            if (session.can('welfare.record_payment'))
              (Icons.volunteer_activism_outlined, l10n.welfareRecordPayment, () async {
                final brief = MemberBrief.fromJson({
                  'id': m.id,
                  'member_number': m.memberNumber,
                  'full_name': m.fullName,
                  'phone_number': m.phoneNumber,
                });
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(l10n.welfareRecordPayment)),
                    body: WelfareCounterTab(initialMember: brief),
                  ),
                ));
              }),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 26,
                    foregroundImage: m.photo != null ? NetworkImage(m.photo!) : null,
                    child: Text(m.firstName.isEmpty ? '?' : m.firstName[0].toUpperCase()),
                  ),
                  title: Text(m.fullName),
                  subtitle: Text('${m.memberNumber} · ${m.phoneNumber}\n${m.idType} ${m.idNumber}'),
                  isThreeLine: true,
                  trailing: StatusChip(m.isKycVerified ? l10n.kycVerified : l10n.kycPending,
                      tone: m.isKycVerified ? Tone.good : Tone.warn),
                ),
              ),
              if (!m.isKycVerified && session.can('members.kyc_verify')) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(l10n.counterVerifyKyc),
                  onPressed: () async {
                    final ok = await confirm(context,
                        title: l10n.counterVerifyKyc, body: l10n.counterVerifyKycBody, action: l10n.counterVerifyKyc);
                    if (!ok || !context.mounted) return;
                    if (await runAction(context, () => session.api!.verifyKyc(m.id), done: l10n.kycVerified)) reload();
                  },
                ),
              ],
              if (data.statement != null) ...[
                SectionTitle(l10n.savingsTitle),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(children: [
                      InfoRow(l10n.shareCapital, money(context, data.statement!.sharesBalance)),
                      InfoRow(l10n.savingsTotal, money(context, data.statement!.savingsTotal)),
                      if (data.statement!.savingsPledged > Decimal.zero)
                        InfoRow(l10n.counterPledged, money(context, data.statement!.savingsPledged)),
                      for (final a in data.statement!.savingsAccounts) InfoRow(a.productName, a.accountNumber),
                    ]),
                  ),
                ),
              ],
              if (actions.isNotEmpty) ...[
                SectionTitle(l10n.counterActions),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final a in actions) ActionChip(avatar: Icon(a.$1, size: 18), label: Text(a.$2), onPressed: a.$3),
                ]),
              ],
              if (data.loans != null) ...[
                SectionTitle(l10n.navLoans),
                if (data.loans!.isEmpty) EmptyNote(l10n.noLoans),
                for (final loan in data.loans!)
                  Card(
                    child: ListTile(
                      title: Text(loan.productName),
                      subtitle: Text(formatDate(context, loan.appliedAt)),
                      trailing: Builder(builder: (context) {
                        final (label, tone) = loanStatus(l10n, loan.status);
                        return StatusChip(label, tone: tone);
                      }),
                      onTap: () async {
                        await Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => StaffLoanScreen(loanId: loan.id)));
                        reload();
                      },
                    ),
                  ),
              ],
              if (data.statement == null && data.loans == null)
                Padding(padding: const EdgeInsets.only(top: 16), child: Text(l10n.counterLimitedView, style: theme.textTheme.bodySmall)),
            ],
          );
        },
      ),
    );
  }
}

enum _CounterAction { deposit, shares, withdraw }

/// Cash received or paid at the counter. Posts to the ledger immediately.
class _CounterSheet extends StatefulWidget {
  final _CounterAction action;
  final Member member;
  final Statement? statement;
  const _CounterSheet({required this.action, required this.member, required this.statement});

  @override
  State<_CounterSheet> createState() => _CounterSheetState();
}

class _CounterSheetState extends State<_CounterSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  SavingsProduct? _product;
  SavingsAccount? _account;
  late final Future<List<SavingsProduct>> _products = context.read<Session>().api!.savingsProducts();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String _title(BuildContext context) => switch (widget.action) {
        _CounterAction.deposit => context.l10n.actionDeposit,
        _CounterAction.shares => context.l10n.actionContribute,
        _CounterAction.withdraw => context.l10n.counterWithdraw,
      };

  Future<void> _submit() async {
    final l10n = context.l10n;
    final amount = Money.parseUserInput(_amount.text);
    if (amount == null) return setState(() => _error = l10n.amountInvalid);
    if (widget.action == _CounterAction.deposit && _product == null) return setState(() => _error = l10n.welfareRequiredProduct);
    if (widget.action == _CounterAction.withdraw && _account == null) return setState(() => _error = l10n.required);
    if (widget.action == _CounterAction.withdraw) {
      final ok = await confirm(context,
          title: l10n.counterWithdraw,
          body: l10n.counterWithdrawConfirm(money(context, amount), widget.member.fullName),
          action: l10n.counterWithdraw);
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<Session>().api!;
      final note = _note.text.trim();
      switch (widget.action) {
        case _CounterAction.deposit:
          await api.counterDeposit(widget.member.id, productId: _product!.id, amount: amount, date: _date, note: note);
        case _CounterAction.shares:
          await api.counterContributeShares(widget.member.id, amount: amount, date: _date, note: note);
        case _CounterAction.withdraw:
          await api.counterWithdraw(widget.member.id, savingsAccountId: _account!.id, amount: amount, date: _date, note: note);
      }
      if (!mounted) return;
      showSnack(context, l10n.counterRecorded);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_title(context), style: Theme.of(context).textTheme.titleLarge),
            Text('${widget.member.fullName} · ${widget.member.memberNumber}'),
            const SizedBox(height: 16),
            if (widget.action == _CounterAction.deposit)
              FutureBuilder<List<SavingsProduct>>(
                future: _products,
                builder: (context, snap) => DropdownButtonFormField<SavingsProduct>(
                  initialValue: _product,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.savingsProduct),
                  items: [for (final p in snap.data ?? const <SavingsProduct>[]) DropdownMenuItem(value: p, child: Text(p.name))],
                  onChanged: (p) => setState(() => _product = p),
                ),
              ),
            if (widget.action == _CounterAction.withdraw)
              DropdownButtonFormField<SavingsAccount>(
                initialValue: _account,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.counterFromAccount),
                items: [
                  for (final a in widget.statement?.savingsAccounts ?? const <SavingsAccount>[])
                    DropdownMenuItem(value: a, child: Text('${a.productName} · ${a.accountNumber}')),
                ],
                onChanged: (a) => setState(() => _account = a),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.amount, prefixText: '${context.read<Session>().currency} '),
            ),
            DateField(label: l10n.journalDate, value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d)),
            TextField(controller: _note, decoration: InputDecoration(labelText: l10n.welfareReference)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_title(context))),
          ],
        ),
      ),
    );
  }
}
