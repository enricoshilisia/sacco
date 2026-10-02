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
import '../../widgets/inuka_app_bar.dart';
import '../../widgets/labels.dart';

/// The Loans Officer writing a loan for a member who asked in person. The
/// rate starts at the product's standard one and can be changed for this
/// loan when the committee has agreed something else.
class NewLoanScreen extends StatefulWidget {
  final String? memberId;
  const NewLoanScreen({super.key, this.memberId});

  @override
  State<NewLoanScreen> createState() => _NewLoanScreenState();
}

class _NewLoanScreenState extends State<NewLoanScreen> {
  List<MemberListItem>? _members;
  List<LoanProduct>? _products;
  MemberListItem? _member;
  LoanProduct? _product;
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _purpose = TextEditingController();
  int _termMonths = 3;
  String _period = 'PER_MONTH';
  bool _busy = false;
  Decimal? _savings;

  @override
  void initState() {
    super.initState();
    final api = context.read<Session>().api!;
    api.loanProducts().then((list) {
      if (!mounted) return;
      setState(() {
        _products = list;
        if (list.isNotEmpty) _useProduct(list.first);
      });
    }).catchError((_) {});
    api.searchMembers('').then((list) {
      if (!mounted) return;
      setState(() {
        _members = list;
        _member = widget.memberId == null ? null : list.where((m) => m.id == widget.memberId).firstOrNull;
      });
      if (_member != null) _loadSavings(_member!);
    }).catchError((_) {});
  }

  void _useProduct(LoanProduct product) {
    _product = product;
    _rate.text = Money.percent(product.interestRate);
    _period = product.interestPeriod;
    _termMonths = product.minTermMonths.clamp(1, product.maxTermMonths);
  }

  Future<void> _loadSavings(MemberListItem member) async {
    try {
      final statement = await context.read<Session>().api!.memberStatement(member.id);
      if (mounted) setState(() => _savings = statement.sharesBalance + statement.savingsTotal);
    } catch (_) {}
  }

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Decimal? get _maxBorrowable {
    final multiple = _product?.maxMultipleOfDeposits;
    final savings = _savings;
    if (multiple == null || savings == null) return null;
    return savings * multiple;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final amount = Money.parseUserInput(_amount.text);
    final rate = Money.parseUserInput(_rate.text);
    if (_member == null || _product == null || amount == null || amount <= Decimal.zero) {
      showSnack(context, l10n.chooseMemberAndAmount, error: true);
      return;
    }
    if (rate == null) {
      showSnack(context, l10n.rateInvalid, error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => context.read<Session>().api!.createLoanForMember(
            memberId: _member!.id,
            productId: _product!.id,
            amount: amount,
            termMonths: _termMonths,
            purpose: _purpose.text.trim(),
            interestRate: Money.percentToFraction(rate),
            interestPeriod: _period,
          ),
      done: l10n.loanCreated,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final max = _maxBorrowable;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.newLoan),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        DropdownButtonFormField<MemberListItem>(
          initialValue: _member,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.member),
          items: [
            for (final m in _members ?? const <MemberListItem>[])
              DropdownMenuItem(value: m, child: Text('${m.fullName} · ${m.memberNumber}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            setState(() {
              _member = v;
              _savings = null;
            });
            if (v != null) _loadSavings(v);
          },
        ),
        if (_savings != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              max == null
                  ? l10n.memberSavingsIs(money(context, _savings!))
                  : l10n.memberCanBorrowUpTo(money(context, _savings!), money(context, max)),
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<LoanProduct>(
          initialValue: _product,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.loanProduct),
          items: [
            for (final p in _products ?? const <LoanProduct>[])
              DropdownMenuItem(value: p, child: Text('${p.name} · ${interestMethod(l10n, p.interestMethod)}')),
          ],
          onChanged: (v) => setState(() {
            if (v != null) _useProduct(v);
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.loanAmount, prefixText: '${context.read<Session>().currency} '),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.interestRate, suffixText: '%'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _period,
              decoration: InputDecoration(labelText: l10n.interestPeriod),
              items: [
                DropdownMenuItem(value: 'PER_MONTH', child: Text(l10n.perMonth)),
                DropdownMenuItem(value: 'PER_YEAR', child: Text(l10n.perYear)),
              ],
              onChanged: (v) => setState(() => _period = v ?? _period),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(l10n.interestRateHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(l10n.loanTermMonths)),
          IconButton(
            onPressed: _termMonths > (_product?.minTermMonths ?? 1) ? () => setState(() => _termMonths--) : null,
            icon: const Icon(Icons.remove),
          ),
          Text('$_termMonths', style: theme.textTheme.titleMedium),
          IconButton(
            onPressed: _termMonths < (_product?.maxTermMonths ?? 12) ? () => setState(() => _termMonths++) : null,
            icon: const Icon(Icons.add),
          ),
        ]),
        TextField(controller: _purpose, decoration: InputDecoration(labelText: l10n.loanPurpose)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.request_quote_rounded),
          label: Text(l10n.newLoan),
        ),
        const SizedBox(height: 8),
        Text(l10n.newLoanHelp, style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

/// The loan rules: the standard rate, how much of their savings a member
/// may borrow, how long they have, and whether guarantors are needed.
class LoanRulesScreen extends StatefulWidget {
  const LoanRulesScreen({super.key});

  @override
  State<LoanRulesScreen> createState() => _LoanRulesScreenState();
}

class _LoanRulesScreenState extends State<LoanRulesScreen> {
  final _view = GlobalKey<AsyncViewState<List<LoanProduct>>>();

  Future<void> _edit(LoanProduct product) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _LoanRuleDialog(product: product));
    if (saved == true) _view.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: InukaAppBar(title: l10n.loanRules),
      body: AsyncView<List<LoanProduct>>(
        key: _view,
        load: context.read<Session>().api!.loanProducts,
        builder: (context, products, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(l10n.loanRulesHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            for (final p in products) ...[
              GlassCard(
                onTap: () => _edit(p),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                    Text('${Money.percent(p.interestRate)}% ${p.interestPeriod == 'PER_MONTH' ? l10n.pmShort : l10n.paShort}',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 4),
                  Text([
                    interestMethod(l10n, p.interestMethod),
                    if (p.maxMultipleOfDeposits != null)
                      l10n.upToTimesSavings(Money.percent(p.maxMultipleOfDeposits! * Decimal.fromInt(100))),
                    l10n.monthsRange(p.minTermMonths, p.maxTermMonths),
                    if (p.requiresGuarantors) l10n.guarantorsNeeded(p.minGuarantors),
                  ].join(' · '), style: theme.textTheme.bodySmall),
                ]),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoanRuleDialog extends StatefulWidget {
  final LoanProduct product;
  const _LoanRuleDialog({required this.product});

  @override
  State<_LoanRuleDialog> createState() => _LoanRuleDialogState();
}

class _LoanRuleDialogState extends State<_LoanRuleDialog> {
  late final _rate = TextEditingController(text: Money.percent(widget.product.interestRate));
  late final _multiple =
      TextEditingController(text: widget.product.maxMultipleOfDeposits?.toString() ?? '');
  late int _minTerm = widget.product.minTermMonths;
  late int _maxTerm = widget.product.maxTermMonths;
  late String _period = widget.product.interestPeriod;
  late String _method = widget.product.interestMethod;
  late bool _guarantors = widget.product.requiresGuarantors;
  bool _busy = false;

  @override
  void dispose() {
    _rate.dispose();
    _multiple.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final rate = Money.parseUserInput(_rate.text);
    if (rate == null) {
      showSnack(context, l10n.rateInvalid, error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => context.read<Session>().api!.saveLoanProduct(
            widget.product.id,
            interestRate: Money.percentToFraction(rate),
            interestPeriod: _period,
            interestMethod: _method,
            maxMultipleOfDeposits: Money.parseUserInput(_multiple.text),
            minTermMonths: _minTerm,
            maxTermMonths: _maxTerm,
            requiresGuarantors: _guarantors,
          ),
      done: l10n.saved,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.product.name),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.interestRate, suffixText: '%'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _period,
                decoration: InputDecoration(labelText: l10n.interestPeriod),
                items: [
                  DropdownMenuItem(value: 'PER_MONTH', child: Text(l10n.perMonth)),
                  DropdownMenuItem(value: 'PER_YEAR', child: Text(l10n.perYear)),
                ],
                onChanged: (v) => setState(() => _period = v ?? _period),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: InputDecoration(labelText: l10n.interestMethodLabel),
            items: [
              DropdownMenuItem(value: 'FLAT', child: Text(interestMethod(l10n, 'FLAT'))),
              DropdownMenuItem(value: 'REDUCING_BALANCE', child: Text(interestMethod(l10n, 'REDUCING_BALANCE'))),
            ],
            onChanged: (v) => setState(() => _method = v ?? _method),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _multiple,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.maxMultipleOfSavings, helperText: l10n.maxMultipleHelp),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text(l10n.monthsRange(_minTerm, _maxTerm))),
            IconButton(onPressed: _minTerm > 1 ? () => setState(() => _minTerm--) : null, icon: const Icon(Icons.remove)),
            IconButton(onPressed: _maxTerm < 60 ? () => setState(() => _maxTerm++) : null, icon: const Icon(Icons.add)),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _guarantors,
            title: Text(l10n.guarantorsRequired),
            onChanged: (v) => setState(() => _guarantors = v),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: _busy ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
