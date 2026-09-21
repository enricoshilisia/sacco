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
import '../../widgets/glass.dart';
import '../../widgets/labels.dart';
import '../../models/welfare.dart';
import '../welfare/welfare_counter.dart';
import 'loan_desk_screen.dart';
import 'admission_screens.dart';
import '../../core/admin_api.dart';
import '../../models/admin.dart';
import '../dashboard_screen.dart' show ProbationCard;
import 'package:uuid/uuid.dart';
import '../../widgets/inuka_app_bar.dart';

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
    final session = context.watch<Session>();
    final admissions = session.can('members.register') || session.can('members.approve_admission');
    return Scaffold(
      appBar: InukaAppBar(
        title: l10n.leaderMembers,
        actions: [
          if (admissions)
            IconButton(
              tooltip: l10n.applicationsTitle,
              icon: const Icon(Icons.how_to_reg_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApplicationsView())),
            ),
        ],
      ),
      floatingActionButton: session.can('members.register')
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApplicationFormScreen())),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l10n.registerMember),
            )
          : null,
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
              return MembersTable(
                members: members,
                onOpen: (m) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: m.id))),
              );
            },
          ),
        ),
      ]),
    );
  }
}

enum _SortBy { name, number, status, profile }

/// The member register as a modern table: frosted-glass card, sticky header,
/// tap a column to sort, alternating row shading, avatars, status chips.
/// The phone column hides on narrow screens so it stays readable.
class MembersTable extends StatefulWidget {
  final List<MemberListItem> members;
  final ValueChanged<MemberListItem> onOpen;
  const MembersTable({super.key, required this.members, required this.onOpen});

  @override
  State<MembersTable> createState() => _MembersTableState();
}

class _MembersTableState extends State<MembersTable> {
  _SortBy _sortBy = _SortBy.number;
  bool _ascending = true;

  void _sort(_SortBy by) => setState(() {
        if (_sortBy == by) {
          _ascending = !_ascending;
        } else {
          _sortBy = by;
          _ascending = true;
        }
      });

  List<MemberListItem> get _sorted {
    int compare(MemberListItem a, MemberListItem b) => switch (_sortBy) {
          _SortBy.name => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          _SortBy.number => a.memberNumber.compareTo(b.memberNumber),
          _SortBy.status => a.status.compareTo(b.status),
          _SortBy.profile => a.profileStatus.compareTo(b.profileStatus),
        };
    final list = [...widget.members]..sort(compare);
    return _ascending ? list : list.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final wide = MediaQuery.of(context).size.width >= 420;
    final rows = _sorted;

    Widget header(String label, _SortBy by, {int flex = 1, TextAlign align = TextAlign.start}) => Expanded(
          flex: flex,
          child: InkWell(
            onTap: () => _sort(by),
            child: Row(
              mainAxisAlignment: align == TextAlign.end ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(label.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                        color: _sortBy == by ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      )),
                ),
                if (_sortBy == by)
                  Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 13, color: theme.colorScheme.primary),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        radius: 20,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                theme.colorScheme.primary.withValues(alpha: 0.10),
                theme.colorScheme.secondary.withValues(alpha: 0.08),
              ]),
            ),
            child: Row(children: [
              header(l10n.tableMember, _SortBy.name, flex: 5),
              if (wide) header(l10n.phoneNumber, _SortBy.number, flex: 3),
              header(l10n.tableStatus, _SortBy.status, flex: 2),
              header(l10n.tableProfile, _SortBy.profile, flex: 3, align: TextAlign.end),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: rows.length + 1,
              itemBuilder: (context, i) {
                if (i == rows.length) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(l10n.tableCount(rows.length),
                        textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  );
                }
                final m = rows[i];
                final (profileLabel, profileTone) = switch (m.profileStatus) {
                  'APPROVED' => (l10n.statusApproved, Tone.good),
                  'PENDING' => (l10n.statusAwaitingApproval, Tone.warn),
                  _ => (l10n.profileNotSubmitted, Tone.neutral),
                };
                return Material(
                  color: i.isOdd ? theme.colorScheme.onSurface.withValues(alpha: 0.03) : Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onOpen(m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Expanded(
                          flex: 5,
                          child: Row(children: [
                            _Avatar(name: m.fullName, photo: m.photo),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m.fullName,
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(m.memberNumber,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ]),
                            ),
                          ]),
                        ),
                        if (wide)
                          Expanded(
                            flex: 3,
                            child: Text(m.phoneNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                          ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _Dot(active: m.status == 'ACTIVE', label: _statusLabel(context, m.status)),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Align(alignment: Alignment.centerRight, child: StatusChip(profileLabel, tone: profileTone)),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  String _statusLabel(BuildContext context, String status) => switch (status) {
        'ACTIVE' => context.l10n.active,
        'DORMANT' => context.l10n.memberDormant,
        'EXITED' => context.l10n.memberExited,
        _ => status,
      };
}

class _Avatar extends StatelessWidget {
  final String name;
  final String photo;
  const _Avatar({required this.name, required this.photo});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();
    final fallback = Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)));
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFFE2342B), Color(0xFFF28A1E)]),
      ),
      child: ClipOval(
        child: photo.isEmpty
            ? fallback
            : Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  final String label;
  const _Dot({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2E9E4F) : Theme.of(context).colorScheme.outline;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
    ]);
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
      appBar: InukaAppBar(title: l10n.leaderMember),
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
                    appBar: InukaAppBar(title: l10n.welfareRecordPayment),
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
              _VerificationSection(memberId: m.id),
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


/// Probation status of a member, and recording a registration fee paid at
/// the counter (members.record_fee). Hidden for verified members.
class _VerificationSection extends StatefulWidget {
  final String memberId;
  const _VerificationSection({required this.memberId});

  @override
  State<_VerificationSection> createState() => _VerificationSectionState();
}

class _VerificationSectionState extends State<_VerificationSection> {
  late Future<Verification> _future = context.read<Session>().api!.memberVerification(widget.memberId);

  Future<void> _recordFee(Verification v) async {
    final l10n = context.l10n;
    final amount = TextEditingController(text: v.feeOutstanding.toString());
    final reference = TextEditingController();
    var method = 'CASH';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.recordRegistrationFee),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.amount),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: InputDecoration(labelText: l10n.paymentMethodLabel),
              items: [
                for (final m in const ['CASH', 'BANK', 'MOBILE_MONEY'])
                  DropdownMenuItem(value: m, child: Text(paymentMethod(l10n, m))),
              ],
              onChanged: (v) => setState(() => method = v ?? method),
            ),
            const SizedBox(height: 10),
            TextField(controller: reference, decoration: InputDecoration(labelText: l10n.receiptReference)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    final value = Money.parseUserInput(amount.text);
    final ref = reference.text.trim();
    amount.dispose();
    reference.dispose();
    if (result != true || !mounted) return;
    if (value == null || value <= Decimal.zero) {
      showSnack(context, l10n.amountInvalid, error: true);
      return;
    }
    final api = context.read<Session>().api!;
    final key = const Uuid().v4();
    if (await runAction(
          context,
          () => api.recordRegistrationFee(widget.memberId,
              amount: value, method: method, paidOn: DateTime.now(), idempotencyKey: key, reference: ref),
          done: l10n.registrationFeeRecorded,
        ) &&
        mounted) {
      setState(() => _future = api.memberVerification(widget.memberId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return FutureBuilder<Verification>(
      future: _future,
      builder: (context, snap) {
        final v = snap.data;
        if (v == null || v.verified) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ProbationCard(verification: v),
            if (!v.feeDone && session.can('members.record_fee')) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(l10n.recordRegistrationFee),
                onPressed: () => _recordFee(v),
              ),
            ],
          ]),
        );
      },
    );
  }
}
