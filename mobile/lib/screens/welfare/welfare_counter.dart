import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/welfare.dart';
import '../../widgets/common.dart';
import 'member_picker.dart';
import 'welfare_screen.dart';

/// Staff counter: look up any member's welfare position and record a
/// cash/bank payment. The backend clears their oldest dues first and puts
/// the rest on their yearly balance.
class WelfareCounterTab extends StatefulWidget {
  final MemberBrief? initialMember;
  const WelfareCounterTab({super.key, this.initialMember});

  @override
  State<WelfareCounterTab> createState() => _WelfareCounterTabState();
}

class _WelfareCounterTabState extends State<WelfareCounterTab> {
  late MemberBrief? _member = widget.initialMember;
  int _version = 0;

  Future<void> _pick() async {
    final picked = await pickMember(context);
    if (picked != null) setState(() => _member = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_search_outlined),
            title: Text(_member?.fullName ?? l10n.welfarePickMember),
            subtitle: _member == null ? null : Text('${_member!.memberNumber} · ${_member!.phoneNumber}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pick,
          ),
        ),
        const SizedBox(height: 12),
        if (_member != null)
          FutureBuilder<MemberWelfare>(
            key: ValueKey('${_member!.id}$_version'),
            future: session.api!.memberWelfare(_member!.id),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) {
                return ErrorRetry(message: errorText(context, snap.error!), onRetry: () => setState(() => _version++));
              }
              final data = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WelfareSummaryCard(
                    summary: data.summary,
                    payLabel: l10n.welfareRecordPayment,
                    onPay: () async {
                      final recorded = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        useSafeArea: true,
                        builder: (_) => ChangeNotifierProvider.value(
                          value: session,
                          child: _CounterPaymentSheet(member: data.member, summary: data.summary),
                        ),
                      );
                      if (recorded == true) setState(() => _version++);
                    },
                  ),
                  WelfareHistory(data: data),
                ],
              );
            },
          )
        else
          EmptyNote(l10n.welfareCounterHelp),
      ],
    );
  }
}

class _CounterPaymentSheet extends StatefulWidget {
  final MemberBrief member;
  final WelfareSummary summary;
  const _CounterPaymentSheet({required this.member, required this.summary});

  @override
  State<_CounterPaymentSheet> createState() => _CounterPaymentSheetState();
}

class _CounterPaymentSheetState extends State<_CounterPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: (widget.summary.owed + widget.summary.yearlyRemaining).toStringAsFixed(2),
  );
  final _reference = TextEditingController();
  String _method = 'CASH';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
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
      await context.read<Session>().api!.recordWelfarePayment(
            memberId: widget.member.id,
            amount: Money.parseUserInput(_amount.text)!,
            method: _method,
            date: DateTime.now(),
            reference: _reference.text.trim(),
          );
      if (!mounted) return;
      showSnack(context, context.l10n.welfarePaymentRecorded);
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.welfareRecordPayment, style: Theme.of(context).textTheme.titleLarge),
            Text('${widget.member.fullName} · ${widget.member.memberNumber}'),
            const SizedBox(height: 4),
            Text(l10n.welfareAllocationHelp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.amount, prefixText: '${context.read<Session>().currency} '),
              validator: (v) => Money.parseUserInput(v ?? '') == null ? l10n.amountInvalid : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'CASH', label: Text(l10n.methodCash)),
                ButtonSegment(value: 'BANK', label: Text(l10n.methodBank)),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _reference, decoration: InputDecoration(labelText: l10n.welfareReference)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.welfareRecordPayment)),
          ],
        ),
      ),
    );
  }
}
