import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/money.dart';
import '../core/session.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/labels.dart';
import 'loan_detail_screen.dart';

/// Eligibility (multiplier on deposits, guarantors, rules engine) is
/// decided by the backend - the app never pre-computes a limit, it just
/// shows the product terms and surfaces the backend's answer.
class ApplyLoanScreen extends StatefulWidget {
  const ApplyLoanScreen({super.key});

  @override
  State<ApplyLoanScreen> createState() => _ApplyLoanScreenState();
}

class _ApplyLoanScreenState extends State<ApplyLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _term = TextEditingController();
  final _purpose = TextEditingController();
  LoanProduct? _product;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _term.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final loan = await context.read<Session>().api!.applyForLoan(
            productId: _product!.id,
            amount: Money.parseUserInput(_amount.text)!,
            termMonths: int.parse(_term.text.trim()),
            purpose: _purpose.text.trim(),
          );
      if (!mounted) return;
      showSnack(context, context.l10n.applied);
      final navigator = Navigator.of(context);
      navigator.pop(true);
      // Straight on to adding guarantors, the next step of the application.
      navigator.push(MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan.id)));
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
      appBar: AppBar(title: Text(l10n.applyTitle)),
      body: AsyncView<List<LoanProduct>>(
        load: () => context.read<Session>().api!.loanProducts(),
        builder: (context, products, reload) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<LoanProduct>(
                initialValue: _product,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.loanProduct),
                items: [for (final p in products) DropdownMenuItem(value: p, child: Text(p.name))],
                validator: (v) => v == null ? l10n.required : null,
                onChanged: (v) => setState(() => _product = v),
              ),
              if (_product != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.productTerms(
                    Money.percent(_product!.interestRate),
                    interestMethod(l10n, _product!.interestMethod),
                    _product!.minTermMonths,
                    _product!.maxTermMonths,
                    _product!.maxMultipleOfDeposits == null ? '—' : Money.format(_product!.maxMultipleOfDeposits!),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (_product!.requiresGuarantors)
                  Text(l10n.guarantorsNeeded(_product!.minGuarantors), style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.amount,
                  prefixText: '${context.read<Session>().currency} ',
                ),
                validator: (v) => Money.parseUserInput(v ?? '') == null ? l10n.amountInvalid : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _term,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.term),
                validator: (v) {
                  final p = _product;
                  final months = int.tryParse((v ?? '').trim());
                  if (p == null) return null;
                  if (months == null || months < p.minTermMonths || months > p.maxTermMonths) {
                    return l10n.termInvalid(p.minTermMonths, p.maxTermMonths);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purpose,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.purpose),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.applySubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
