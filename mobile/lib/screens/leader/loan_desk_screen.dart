import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/leader_api.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/labels.dart';

enum LoanQueue { appraise, decide, disburse, active }

/// Loans through their approval chain: Loan Officer appraises, Credit
/// Committee decides, Treasurer disburses, and repayments are recorded on
/// active loans. Each queue shows only to roles that can act on it.
class LoanDeskScreen extends StatelessWidget {
  final LoanQueue? initialQueue;
  const LoanDeskScreen({super.key, this.initialQueue});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final queues = <(LoanQueue, String, List<String>)>[
      if (session.can('loans.appraise')) (LoanQueue.appraise, l10n.queueAppraise, const ['PENDING_APPRAISAL']),
      if (session.profile?.canAny(const ['loans.approve', 'loans.reject']) ?? false)
        (LoanQueue.decide, l10n.queueDecide, const ['APPRAISED']),
      if (session.can('loans.disburse')) (LoanQueue.disburse, l10n.queueDisburse, const ['APPROVED', 'DISBURSED']),
      if (session.can('loans.repay') || session.can('loans.view')) (LoanQueue.active, l10n.queueActive, const ['ACTIVE']),
    ];
    final initial = queues.indexWhere((q) => q.$1 == initialQueue);
    return DefaultTabController(
      length: queues.length,
      initialIndex: initial < 0 ? 0 : initial,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.leaderLoanDesk),
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final q in queues) Tab(text: q.$2)]),
        ),
        body: TabBarView(children: [for (final q in queues) _Queue(statuses: q.$3)]),
      ),
    );
  }
}

class _Queue extends StatelessWidget {
  final List<String> statuses;
  const _Queue({required this.statuses});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final api = context.read<Session>().api!;
    return AsyncView<List<Loan>>(
      load: () => api.loansByStatus(statuses),
      builder: (context, loans, reload) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (loans.isEmpty) EmptyNote(l10n.queueEmpty),
          for (final loan in loans) ...[
            Card(
              child: ListTile(
                title: Text('${loan.memberName} · ${loan.memberNumber}'),
                subtitle: Text('${loan.productName} · ${l10n.termMonths(loan.termMonths)} · ${formatDate(context, loan.appliedAt)}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money(context, loan.isActive ? loan.outstandingBalance : loan.amountRequested),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (loan.isOverdue)
                      Text(l10n.queueDaysOverdue(loan.daysOverdue),
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
                  ],
                ),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StaffLoanScreen(loanId: loan.id)));
                  reload();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// One loan from the staff side, with the action its status and the
/// viewer's role allow.
class StaffLoanScreen extends StatelessWidget {
  final String loanId;
  const StaffLoanScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final api = session.api!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loanDetail)),
      body: AsyncView<Loan>(
        load: () => api.loan(loanId),
        builder: (context, loan, reload) {
          final theme = Theme.of(context);
          final (label, tone) = loanStatus(l10n, loan.status);
          final consented = loan.guarantors.where((g) => g.status == 'CONSENTED').toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${loan.memberName} · ${loan.memberNumber}', style: theme.textTheme.titleMedium)),
                      StatusChip(label, tone: tone),
                    ]),
                    const SizedBox(height: 8),
                    InfoRow(l10n.loanProduct, loan.productName),
                    InfoRow(l10n.requested, money(context, loan.amountRequested)),
                    InfoRow(l10n.term, l10n.termMonths(loan.termMonths)),
                    InfoRow(l10n.interest, '${Money.percent(loan.interestRate)}% · ${interestMethod(l10n, loan.interestMethod)}'),
                    if (loan.purpose.isNotEmpty) InfoRow(l10n.purpose, loan.purpose),
                    if (loan.isActive) InfoRow(l10n.outstanding, money(context, loan.outstandingBalance)),
                    if (loan.isOverdue) InfoRow(l10n.queueArrears, l10n.overdue(loan.daysOverdue, money(context, loan.amountOverdue))),
                    if (loan.appraisedBy.isNotEmpty) InfoRow(l10n.queueAppraisedBy, loan.appraisedBy),
                    if (loan.appraisalNotes.isNotEmpty) InfoRow(l10n.queueAppraisalNotes, loan.appraisalNotes),
                    if (loan.decidedBy.isNotEmpty) InfoRow(l10n.welfareDecidedBy, loan.decidedBy),
                    if (loan.decisionNotes.isNotEmpty) InfoRow(l10n.decisionNotes, loan.decisionNotes),
                  ]),
                ),
              ),
              SectionTitle(l10n.guarantors),
              Card(
                child: Column(children: [
                  if (loan.guarantors.isEmpty) EmptyNote(l10n.noGuarantors),
                  for (final g in loan.guarantors)
                    ListTile(
                      dense: true,
                      title: Text('${g.guarantorName} · ${g.guarantorMemberNumber}'),
                      subtitle: Text(money(context, g.pledgedAmount)),
                      trailing: Builder(builder: (context) {
                        final (gl, gt) = guarantorStatus(l10n, g.status);
                        return StatusChip(gl, tone: gt);
                      }),
                    ),
                  if (consented.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(l10n.queuePledged(money(context, Money.sum(consented.map((g) => g.pledgedAmount))))),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              ..._actions(context, loan, reload),
              if (loan.schedule.isNotEmpty) ...[
                SectionTitle(l10n.schedule),
                Card(
                  child: Column(children: [
                    for (final row in loan.schedule)
                      ListTile(
                        dense: true,
                        leading: Icon(row.isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 18, color: row.isPaid ? theme.colorScheme.primary : theme.colorScheme.outline),
                        title: Text(l10n.installment(row.installmentNumber, formatDate(context, row.dueDate))),
                        trailing: Text(row.isPaid ? l10n.paid : money(context, row.totalDue - row.paid)),
                      ),
                  ]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _actions(BuildContext context, Loan loan, Future<void> Function() reload) {
    final l10n = context.l10n;
    final session = context.read<Session>();
    final api = session.api!;
    final widgets = <Widget>[];

    if (loan.status == 'PENDING_APPRAISAL' && session.can('loans.appraise')) {
      widgets.add(FilledButton.icon(
        icon: const Icon(Icons.rate_review_outlined),
        label: Text(l10n.queueAppraiseAction),
        onPressed: () async {
          final notes = await askText(context, title: l10n.queueAppraiseAction, label: l10n.queueAppraisalNotes);
          if (notes == null || !context.mounted) return;
          if (await runAction(context, () => api.appraiseLoan(loan.id, notes), done: l10n.queueAppraised)) reload();
        },
      ));
    }
    if (loan.status == 'APPRAISED') {
      if (session.can('loans.approve')) {
        widgets.add(FilledButton.icon(
          icon: const Icon(Icons.check),
          label: Text(l10n.approve),
          onPressed: () async {
            final notes = await askText(context, title: l10n.approve, label: l10n.welfareNotesOptional);
            if (notes == null || !context.mounted) return;
            if (await runAction(context, () => api.decideLoan(loan.id, approve: true, notes: notes), done: l10n.queueApproved)) {
              reload();
            }
          },
        ));
      }
      if (session.can('loans.reject')) {
        widgets.addAll([
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.close),
            label: Text(l10n.reject),
            onPressed: () async {
              final notes = await askText(context, title: l10n.reject, label: l10n.welfareReason, required: true);
              if (notes == null || !context.mounted) return;
              if (await runAction(context, () => api.decideLoan(loan.id, approve: false, notes: notes), done: l10n.queueRejected)) {
                reload();
              }
            },
          ),
        ]);
      }
    }
    if (loan.status == 'APPROVED' && session.can('loans.disburse')) {
      widgets.add(FilledButton.icon(
        icon: const Icon(Icons.outbox_outlined),
        label: Text(l10n.queueDisburseAction),
        onPressed: () async {
          final done = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            useSafeArea: true,
            builder: (_) => ChangeNotifierProvider.value(value: session, child: _DisburseSheet(loan: loan)),
          );
          if (done == true) reload();
        },
      ));
    }
    if (loan.status == 'DISBURSED') {
      widgets.add(Card(child: ListTile(leading: const Icon(Icons.hourglass_top), title: Text(l10n.queueAwaitingProvider))));
    }
    if (loan.isActive && session.can('loans.repay')) {
      widgets.add(FilledButton.icon(
        icon: const Icon(Icons.payments_outlined),
        label: Text(l10n.queueRecordRepayment),
        onPressed: () async {
          final done = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            useSafeArea: true,
            builder: (_) => ChangeNotifierProvider.value(value: session, child: RepaymentSheet(loan: loan)),
          );
          if (done == true) reload();
        },
      ));
    }
    return widgets;
  }
}

class _DisburseSheet extends StatefulWidget {
  final Loan loan;
  const _DisburseSheet({required this.loan});

  @override
  State<_DisburseSheet> createState() => _DisburseSheetState();
}

class _DisburseSheetState extends State<_DisburseSheet> {
  String _method = 'SAVINGS';
  SavingsProduct? _product;
  final _phone = TextEditingController();
  late final Future<List<SavingsProduct>> _products = context.read<Session>().api!.savingsProducts();
  // Reused across retries of the same disbursement (CLAUDE.md rule 4).
  final _idempotencyKey = const Uuid().v4();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_method == 'SAVINGS' && _product == null) return setState(() => _error = l10n.welfareRequiredProduct);
    if (_method == 'MOBILE' && _phone.text.trim().isEmpty) return setState(() => _error = l10n.required);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<Session>().api!;
      if (_method == 'SAVINGS') {
        await api.disburseLoanToSavings(widget.loan.id, _product!.id);
      } else {
        await api.disburseLoanMobileMoney(widget.loan.id, phone: _phone.text.trim(), idempotencyKey: _idempotencyKey);
      }
      if (!mounted) return;
      showSnack(context, l10n.queueDisbursed);
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
      child: FutureBuilder<List<SavingsProduct>>(
        future: _products,
        builder: (context, snap) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.queueDisburseAction, style: Theme.of(context).textTheme.titleLarge),
            Text('${widget.loan.memberName} · ${money(context, widget.loan.amountRequested)}'),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'SAVINGS', label: Text(l10n.queueToSavings)),
                ButtonSegment(value: 'MOBILE', label: Text(l10n.methodMobileMoney)),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 12),
            if (_method == 'SAVINGS')
              DropdownButtonFormField<SavingsProduct>(
                initialValue: _product,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.savingsProduct),
                items: [for (final p in snap.data ?? const <SavingsProduct>[]) DropdownMenuItem(value: p, child: Text(p.name))],
                onChanged: (p) => setState(() => _product = p),
              )
            else
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.phoneNumber),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.queueDisburseAction)),
          ],
        ),
      ),
    );
  }
}

/// Cash repayment recorded at the counter (Teller / Branch Manager).
class RepaymentSheet extends StatefulWidget {
  final Loan loan;
  const RepaymentSheet({super.key, required this.loan});

  @override
  State<RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends State<RepaymentSheet> {
  late final _amount = TextEditingController(
    text: (widget.loan.nextInstallment == null
            ? Decimal.zero
            : widget.loan.nextInstallment!.totalDue - widget.loan.nextInstallment!.paid)
        .toStringAsFixed(2),
  );
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final amount = Money.parseUserInput(_amount.text);
    if (amount == null) return setState(() => _error = l10n.amountInvalid);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().api!.recordLoanRepayment(widget.loan.id, amount: amount, date: _date, note: _note.text.trim());
      if (!mounted) return;
      showSnack(context, l10n.queueRepaymentRecorded);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.queueRecordRepayment, style: Theme.of(context).textTheme.titleLarge),
          Text('${widget.loan.memberName} · ${l10n.outstanding} ${money(context, widget.loan.outstandingBalance)}'),
          const SizedBox(height: 16),
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
          FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.queueRecordRepayment)),
        ],
      ),
    );
  }
}
