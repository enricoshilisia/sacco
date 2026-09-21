import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/api_client.dart';
import '../core/money.dart';
import '../core/session.dart';
import '../models/models.dart';
import '../widgets/common.dart';

enum PayPurpose { savingsDeposit, shareContribution, welfare, registrationFee }

/// Mobile-money payment (M-Pesa STK push / Selcom checkout - whichever
/// provider this SACCO has configured). Returns true if anything was
/// submitted, so the caller can refresh balances.
Future<bool> showPaySheet(
  BuildContext context, {
  required PayPurpose purpose,
  String? productId,
  Decimal? initialAmount,
}) async {
  // Tracked outside the sheet: a member can swipe it away mid-wait, which
  // pops with no result even though a payment request already went out.
  final submitted = ValueNotifier(false);
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<Session>(),
      child: _PaySheet(
        purpose: purpose,
        initialProductId: productId,
        initialAmount: initialAmount,
        submitted: submitted,
      ),
    ),
  );
  final result = submitted.value;
  submitted.dispose();
  return result;
}

enum _Phase { form, waiting, success, failed, timedOut }

class _PaySheet extends StatefulWidget {
  final PayPurpose purpose;
  final String? initialProductId;
  final Decimal? initialAmount;
  final ValueNotifier<bool> submitted;
  const _PaySheet({required this.purpose, this.initialProductId, this.initialAmount, required this.submitted});

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  static const _pollEvery = Duration(seconds: 3);
  static const _giveUpAfter = Duration(seconds: 120);

  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _phone = TextEditingController();

  List<SavingsProduct>? _products;
  String? _productId;
  _Phase _phase = _Phase.form;
  bool _submitting = false;
  String? _error;
  Collection? _collection;
  Timer? _poller;
  DateTime? _pollStarted;

  // One key per intended payment (CLAUDE.md rule 4). Reused if the request
  // is retried after a network error - the backend then returns the SAME
  // collection instead of pushing a second prompt. Discarded when the
  // member changes what they're paying, or when the previous attempt has
  // reached a final state (a failed collection's key would just return
  // that failed collection again).
  String? _idempotencyKey;

  bool get _isDeposit => widget.purpose == PayPurpose.savingsDeposit;

  @override
  void initState() {
    super.initState();
    final session = context.read<Session>();
    _phone.text = session.member?.phoneNumber ?? session.profile?.phoneNumber ?? '';
    _productId = widget.initialProductId;
    final initial = widget.initialAmount;
    if (initial != null && initial > Decimal.zero) _amount.text = initial.toStringAsFixed(2);
    for (final c in [_amount, _phone]) {
      c.addListener(_invalidateKey);
    }
    if (_isDeposit) _loadProducts();
  }

  void _invalidateKey() => _idempotencyKey = null;

  Future<void> _loadProducts() async {
    try {
      final products = await context.read<Session>().api!.savingsProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        if (_productId == null && products.length == 1) _productId = products.first.id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    _amount.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = Money.parseUserInput(_amount.text)!;
    final api = context.read<Session>().api!;
    _idempotencyKey ??= const Uuid().v4();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final collection = await api.collect(
        purpose: switch (widget.purpose) {
          PayPurpose.savingsDeposit => 'SAVINGS_DEPOSIT',
          PayPurpose.shareContribution => 'SHARE_CONTRIBUTION',
          PayPurpose.welfare => 'WELFARE_CONTRIBUTION',
          PayPurpose.registrationFee => 'REGISTRATION_FEE',
        },
        productId: _isDeposit ? _productId : null,
        amount: amount,
        phone: _phone.text.trim(),
        idempotencyKey: _idempotencyKey!,
      );
      widget.submitted.value = true;
      if (!mounted) return;
      _collection = collection;
      _settle(collection);
    } on ApiException catch (e) {
      // Network failure: keep the key so a retry can't double-charge.
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _settle(Collection c) {
    if (c.isPending) {
      setState(() => _phase = _Phase.waiting);
      _pollStarted ??= DateTime.now();
      _poller ??= Timer.periodic(_pollEvery, (_) => _poll());
      return;
    }
    _poller?.cancel();
    _poller = null;
    _pollStarted = null;
    _idempotencyKey = null;
    setState(() => _phase = c.status == 'SUCCESS' ? _Phase.success : _Phase.failed);
  }

  Future<void> _poll() async {
    final current = _collection;
    if (current == null) return;
    if (DateTime.now().difference(_pollStarted!) > _giveUpAfter) {
      _poller?.cancel();
      _poller = null;
      if (mounted) setState(() => _phase = _Phase.timedOut);
      return;
    }
    try {
      final updated = await context.read<Session>().api!.myCollection(current.id);
      if (!mounted) return;
      _collection = updated;
      _settle(updated);
    } catch (_) {
      // Transient - keep polling until the give-up deadline.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _poller?.cancel();
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: switch (_phase) {
            _Phase.form => _buildForm(context),
            _Phase.waiting => _StatusView(
                icon: const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
                title: l10n.payWaiting,
                subtitle: money(context, _collection!.amount),
              ),
            _Phase.success => _StatusView(
                icon: Icon(Icons.check_circle, size: 56, color: Theme.of(context).colorScheme.primary),
                title: l10n.paySuccess,
                subtitle: [
                  money(context, _collection!.amount),
                  if (_collection!.providerReceipt.isNotEmpty) l10n.receipt(_collection!.providerReceipt),
                ].join('\n'),
                action: FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.done)),
              ),
            _Phase.failed => _StatusView(
                icon: Icon(Icons.error_outline, size: 56, color: Theme.of(context).colorScheme.error),
                title: _collection!.status == 'CANCELLED' ? l10n.payCancelled : l10n.payFailed,
                subtitle: _collection!.failureReason,
                action: FilledButton.tonal(
                  onPressed: () => setState(() => _phase = _Phase.form),
                  child: Text(l10n.retry),
                ),
              ),
            _Phase.timedOut => _StatusView(
                icon: Icon(Icons.schedule, size: 56, color: Theme.of(context).colorScheme.tertiary),
                title: l10n.payStillPending,
                action: FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.done)),
              ),
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            switch (widget.purpose) {
              PayPurpose.savingsDeposit => l10n.payTitleDeposit,
              PayPurpose.shareContribution => l10n.payTitleContribute,
              PayPurpose.welfare => l10n.payTitleWelfare,
              PayPurpose.registrationFee => l10n.payTitleRegistrationFee,
            },
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            switch (widget.purpose) {
              PayPurpose.savingsDeposit => l10n.savingsHelp,
              PayPurpose.shareContribution => l10n.shareCapitalHelp,
              PayPurpose.welfare => l10n.welfarePayHelp,
              PayPurpose.registrationFee => l10n.registrationFeePayHelp,
            },
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (_isDeposit) ...[
            if (_products == null && _error == null)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<String>(
                initialValue: _productId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.savingsProduct),
                hint: Text(l10n.selectProduct),
                items: [
                  for (final p in _products ?? const <SavingsProduct>[])
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                validator: (v) => v == null ? l10n.required : null,
                onChanged: (v) => setState(() {
                  _productId = v;
                  _invalidateKey();
                }),
              ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.amount,
              prefixText: '${context.read<Session>().currency} ',
            ),
            validator: (v) => Money.parseUserInput(v ?? '') == null ? l10n.amountInvalid : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l10n.payFromPhone, helperText: l10n.mobileMoneyHelp),
            validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.phone_iphone),
            label: Text(l10n.payButton),
          ),
        ],
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const _StatusView({required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(subtitle!, textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: action),
          ],
        ],
      ),
    );
  }
}
