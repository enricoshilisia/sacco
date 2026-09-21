import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/labels.dart';
import 'apply_loan_screen.dart';
import 'loan_detail_screen.dart';

class _LoansData {
  final List<Loan> loans;
  final List<LoanGuarantor> guaranteeRequests;
  _LoansData(this.loans, this.guaranteeRequests);
}

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final _view = GlobalKey<AsyncViewState<_LoansData>>();

  Future<_LoansData> _load() async {
    final api = context.read<Session>().api!;
    final results = await Future.wait([api.myLoans(), api.myGuaranteeRequests()]);
    return _LoansData(results[0] as List<Loan>, results[1] as List<LoanGuarantor>);
  }

  Future<void> _apply() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ApplyLoanScreen()));
    if (created == true) _view.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loansTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _apply,
        icon: const Icon(Icons.add),
        label: Text(l10n.actionApply),
      ),
      body: AsyncView<_LoansData>(
        key: _view,
        load: _load,
        builder: (context, data, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (data.guaranteeRequests.isNotEmpty) ...[
              SectionTitle(l10n.guaranteeRequests),
              for (final request in data.guaranteeRequests) ...[
                _GuaranteeRequestCard(request: request, onChanged: reload),
                const SizedBox(height: 8),
              ],
            ],
            SectionTitle(l10n.myLoans),
            if (data.loans.isEmpty) EmptyNote(l10n.noLoans),
            for (final loan in data.loans) ...[
              _LoanCard(
                loan: loan,
                onTap: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan.id)));
                  reload();
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final VoidCallback onTap;
  const _LoanCard({required this.loan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (label, tone) = loanStatus(l10n, loan.status);
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
                Expanded(child: Text(loan.productName, style: theme.textTheme.titleSmall)),
                StatusChip(label, tone: tone),
              ]),
              const SizedBox(height: 8),
              AmountText(
                loan.isActive ? loan.outstandingBalance : loan.amountRequested,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                loan.isActive
                    ? '${l10n.outstanding} · ${l10n.termMonths(loan.termMonths)}'
                    : '${l10n.requested} · ${l10n.termMonths(loan.termMonths)} · ${formatDate(context, loan.appliedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (loan.isOverdue) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.overdue(loan.daysOverdue, money(context, loan.amountOverdue)),
                  style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuaranteeRequestCard extends StatefulWidget {
  final LoanGuarantor request;
  final Future<void> Function() onChanged;
  const _GuaranteeRequestCard({required this.request, required this.onChanged});

  @override
  State<_GuaranteeRequestCard> createState() => _GuaranteeRequestCardState();
}

class _GuaranteeRequestCardState extends State<_GuaranteeRequestCard> {
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    final l10n = context.l10n;
    final r = widget.request;
    if (accept) {
      // Explicit, informed consent (CLAUDE.md: "Pledges need explicit
      // consent") - accepting locks the guarantor's own deposits.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.confirmAcceptTitle),
          content: Text('${l10n.guaranteeFor(r.borrowerName, money(context, r.pledgedAmount))}\n\n${l10n.guaranteeWarning}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.accept),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<Session>().api!.respondToGuarantee(r.id, accept: accept);
      await widget.onChanged();
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
    final r = widget.request;
    final (label, tone) = guarantorStatus(l10n, r.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(r.borrowerName, style: theme.textTheme.titleSmall)),
              StatusChip(label, tone: tone),
            ]),
            const SizedBox(height: 6),
            Text(l10n.guaranteeFor(r.borrowerName, money(context, r.pledgedAmount))),
            if (r.status == 'PENDING') ...[
              const SizedBox(height: 6),
              Text(l10n.guaranteeWarning,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _respond(false),
                    child: Text(l10n.decline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: _busy ? null : () => _respond(true),
                    child: Text(l10n.accept),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
