import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/money.dart';
import '../core/session.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/labels.dart';
import '../widgets/inuka_app_bar.dart';

class LoanDetailScreen extends StatelessWidget {
  final String loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api!;
    return Scaffold(
      appBar: InukaAppBar(title: context.l10n.loanDetail),
      body: AsyncView<(Loan, List<LoanProduct>)>(
        load: () async {
          final results = await Future.wait([api.loan(loanId), api.loanProducts()]);
          return (results[0] as Loan, results[1] as List<LoanProduct>);
        },
        builder: (context, data, reload) {
          final (loan, products) = data;
          LoanProduct? product;
          for (final p in products) {
            if (p.id == loan.productId) product = p;
          }
          return _LoanDetailBody(loan: loan, product: product, reload: reload);
        },
      ),
    );
  }
}

class _LoanDetailBody extends StatelessWidget {
  final Loan loan;
  final LoanProduct? product;
  final Future<void> Function() reload;
  const _LoanDetailBody({required this.loan, required this.product, required this.reload});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (label, tone) = loanStatus(l10n, loan.status);
    final consented = loan.guarantors.where((g) => g.status == 'CONSENTED').length;

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
                  Expanded(child: Text(loan.productName, style: theme.textTheme.titleMedium)),
                  StatusChip(label, tone: tone),
                ]),
                const SizedBox(height: 12),
                if (loan.isActive) ...[
                  Text(l10n.outstanding, style: theme.textTheme.bodySmall),
                  AmountText(loan.outstandingBalance,
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (loan.isOverdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.overdue(loan.daysOverdue, money(context, loan.amountOverdue)),
                        style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const Divider(height: 24),
                ],
                InfoRow(l10n.requested, money(context, loan.amountRequested)),
                InfoRow(l10n.term, l10n.termMonths(loan.termMonths)),
                InfoRow(l10n.interest,
                    '${Money.percent(loan.interestRate)}% · ${interestMethod(l10n, loan.interestMethod)}'),
                if (loan.purpose.isNotEmpty) InfoRow(l10n.purpose, loan.purpose),
                if (loan.isAutoDecision) InfoRow(l10n.automatedDecision, '✓'),
                if (loan.decisionNotes.isNotEmpty) InfoRow(l10n.decisionNotes, loan.decisionNotes),
              ],
            ),
          ),
        ),
        SectionTitle(l10n.guarantors),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (loan.guarantors.isEmpty) EmptyNote(l10n.noGuarantors),
                for (final g in loan.guarantors)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(g.guarantorName),
                    subtitle: Text('${g.guarantorMemberNumber} · ${money(context, g.pledgedAmount)}'),
                    trailing: Builder(builder: (context) {
                      final (gl, gt) = guarantorStatus(l10n, g.status);
                      return StatusChip(gl, tone: gt);
                    }),
                  ),
                if (loan.awaitingGuarantors) ...[
                  if (product != null && product!.requiresGuarantors)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${l10n.guarantorsNeeded(product!.minGuarantors)} ($consented/${product!.minGuarantors})',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _addGuarantor(context),
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(l10n.addGuarantor),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => _submit(context),
                    child: Text(l10n.submitForAppraisal),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        if (loan.schedule.isNotEmpty) ...[
          SectionTitle(l10n.schedule),
          Card(
            child: Column(
              children: [
                for (final row in loan.schedule)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      row.isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: row.isPaid ? theme.colorScheme.primary : theme.colorScheme.outline,
                      size: 20,
                    ),
                    title: Text(l10n.installment(row.installmentNumber, formatDate(context, row.dueDate))),
                    trailing: Text(row.isPaid ? l10n.paid : money(context, row.totalDue - row.paid),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          if (loan.isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(l10n.repayHelp,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
        ],
        if (loan.repayments.isNotEmpty) ...[
          SectionTitle(l10n.repayments),
          Card(
            child: Column(
              children: [
                for (final r in loan.repayments)
                  ListTile(
                    dense: true,
                    title: Text(money(context, r.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: r.description.isEmpty ? null : Text(r.description),
                    trailing: Text(formatDate(context, r.date)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    try {
      await context.read<Session>().api!.submitForAppraisal(loan.id);
      if (context.mounted) showSnack(context, context.l10n.submitted);
      await reload();
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(context, e), error: true);
    }
  }

  Future<void> _addGuarantor(BuildContext context) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<Session>(),
        child: _AddGuarantorSheet(loanId: loan.id),
      ),
    );
    if (added == true) await reload();
  }
}

class _AddGuarantorSheet extends StatefulWidget {
  final String loanId;
  const _AddGuarantorSheet({required this.loanId});

  @override
  State<_AddGuarantorSheet> createState() => _AddGuarantorSheetState();
}

class _AddGuarantorSheetState extends State<_AddGuarantorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _memberNumber = TextEditingController();
  final _amount = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _memberNumber.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().api!.addGuarantor(
            loanId: widget.loanId,
            memberNumber: _memberNumber.text.trim(),
            pledged: Money.parseUserInput(_amount.text)!,
          );
      if (mounted) Navigator.pop(context, true);
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.addGuarantor, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _memberNumber,
              decoration: InputDecoration(labelText: l10n.guarantorMemberNumber),
              validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.pledgedAmount,
                prefixText: '${context.read<Session>().currency} ',
              ),
              validator: (v) => Money.parseUserInput(v ?? '') == null ? l10n.amountInvalid : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.add)),
          ],
        ),
      ),
    );
  }
}
