import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/welfare.dart';
import '../../widgets/common.dart';
import '../pay_sheet.dart';
import 'welfare_cases.dart';
import 'welfare_counter.dart';

/// Welfare. [staffMode] false (the member's Welfare tab): their own welfare
/// and the rules. [staffMode] true (opened from the Leader hub): the tools
/// their role grants - cases, counter, rules admin and year end.
class WelfareScreen extends StatelessWidget {
  final bool staffMode;
  const WelfareScreen({super.key, this.staffMode = false});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final tabs = <(String, Widget)>[
      if (!staffMode) (l10n.welfareMine, const _MyWelfareTab()),
      if (staffMode && session.can('welfare.view')) (l10n.welfareCases, const WelfareCasesTab()),
      if (staffMode && session.can('welfare.record_payment')) (l10n.welfareCounter, const WelfareCounterTab()),
      (l10n.welfareRules, const _RulesTab()),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(staffMode ? l10n.leaderWelfare : l10n.welfareTitle),
          bottom: TabBar(
            isScrollable: tabs.length > 3,
            tabAlignment: tabs.length > 3 ? TabAlignment.start : null,
            tabs: [for (final t in tabs) Tab(text: t.$1)],
          ),
        ),
        body: TabBarView(children: [for (final t in tabs) t.$2]),
      ),
    );
  }
}

class _MyWelfareTab extends StatelessWidget {
  const _MyWelfareTab();

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api!;
    return AsyncView<MemberWelfare>(
      load: api.myWelfare,
      builder: (context, data, reload) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          WelfareSummaryCard(
            summary: data.summary,
            onPay: () async {
              final s = data.summary;
              // Suggest clearing dues plus whatever's left of this year's contribution.
              final suggested = s.owed + s.yearlyRemaining;
              final paid = await showPaySheet(context, purpose: PayPurpose.welfare, initialAmount: suggested);
              if (paid) await reload();
            },
          ),
          WelfareHistory(data: data),
        ],
      ),
    );
  }
}

/// Balance / owed / yearly-progress card, shared by the member's own view
/// and the staff counter.
class WelfareSummaryCard extends StatelessWidget {
  final WelfareSummary summary;
  final VoidCallback? onPay;
  final String? payLabel;
  const WelfareSummaryCard({super.key, required this.summary, this.onPay, this.payLabel});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final s = summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.volunteer_activism_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(l10n.welfareBalance, style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: 8),
            AmountText(s.balance, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(l10n.welfareBalanceHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const Divider(height: 24),
            InfoRow(l10n.welfareYearly(s.year), '${money(context, s.paidThisYear)} / ${money(context, s.yearlyContribution)}'),
            if (s.yearlyContribution > Decimal.zero) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: _progress(s),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(l10n.welfareOwed, style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
                Text(
                  money(context, s.owed),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: s.owed > Decimal.zero ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
            if (onPay != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.payments_outlined),
                label: Text(payLabel ?? l10n.welfarePay),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Display-only ratio for the progress bar; no money is derived from it.
  double _progress(WelfareSummary s) {
    if (s.paidThisYear >= s.yearlyContribution) return 1;
    final ratio = (s.paidThisYear * Decimal.fromInt(1000) / s.yearlyContribution).toDecimal(scaleOnInfinitePrecision: 0);
    return ratio.toBigInt().toInt() / 1000;
  }
}

/// A member's welfare contributions and payments.
class WelfareHistory extends StatelessWidget {
  final MemberWelfare data;
  const WelfareHistory({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.welfareContributions),
        if (data.contributions.isEmpty) EmptyNote(l10n.welfareNoContributions),
        if (data.contributions.isNotEmpty)
          Card(
            child: Column(
              children: [
                for (final c in data.contributions)
                  ListTile(
                    title: Text(c.caseTypeName),
                    subtitle: Text([
                      c.beneficiaryName,
                      if (c.affectedPerson.isNotEmpty) c.affectedPerson,
                      formatDate(context, c.createdAt),
                    ].join(' · ')),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money(context, c.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (c.outstanding > Decimal.zero)
                          Text(l10n.welfareStillOwed(money(context, c.outstanding)),
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.error))
                        else
                          Text(l10n.paid, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        SectionTitle(l10n.welfarePayments),
        if (data.payments.isEmpty) EmptyNote(l10n.noTransactions),
        if (data.payments.isNotEmpty)
          Card(
            child: Column(
              children: [
                for (final p in data.payments)
                  ListTile(
                    leading: Icon(Icons.arrow_downward, color: theme.colorScheme.primary, size: 18),
                    title: Text(money(context, p.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if (p.appliedToDues > Decimal.zero) l10n.welfareToDues(money(context, p.appliedToDues)),
                      if (p.toBalance > Decimal.zero) l10n.welfareToBalance(money(context, p.toBalance)),
                    ].join(' · ')),
                    trailing: Text(formatDate(context, p.date)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The constitution's welfare rules. Everyone can read them; holders of
/// welfare.manage_rules can edit amounts, and welfare.close_year can close
/// the previous year.
class _RulesTab extends StatefulWidget {
  const _RulesTab();

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  final _view = GlobalKey<AsyncViewState<(List<WelfareCaseType>, Decimal, Set<int>)>>();

  Future<(List<WelfareCaseType>, Decimal, Set<int>)> _load() async {
    final session = context.read<Session>();
    final api = session.api!;
    final results = await Future.wait([
      api.welfareCaseTypes(activeOnly: !session.can('welfare.manage_rules')),
      api.welfareYearlyContribution(),
      session.can('welfare.close_year') ? api.closedWelfareYears() : Future.value(<int>{}),
    ]);
    return (results[0] as List<WelfareCaseType>, results[1] as Decimal, results[2] as Set<int>);
  }

  Future<void> _edit([WelfareCaseType? type]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider.value(value: context.read<Session>(), child: _CaseTypeSheet(type: type)),
    );
    if (saved == true) _view.currentState?.reload();
  }

  Future<void> _editYearly(Decimal current) async {
    final controller = TextEditingController(text: current.toStringAsFixed(2));
    final l10n = context.l10n;
    final value = await showDialog<Decimal>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.welfareYearlyAmount),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(prefixText: '${context.read<Session>().currency} '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, Money.parseUserInput(controller.text)),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      await context.read<Session>().api!.setWelfareYearlyContribution(value);
      _view.currentState?.reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e), error: true);
    }
  }

  Future<void> _closeYear(int year) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.welfareCloseYearTitle(year)),
        content: Text(l10n.welfareCloseYearBody(year)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.welfareCloseYear(year)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<Session>().api!.closeWelfareYear(year);
      if (mounted) showSnack(context, l10n.welfareYearClosing(year));
      _view.currentState?.reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final canEdit = session.can('welfare.manage_rules');
    final theme = Theme.of(context);
    final lastYear = DateTime.now().year - 1;
    return AsyncView<(List<WelfareCaseType>, Decimal, Set<int>)>(
      key: _view,
      load: _load,
      builder: (context, data, reload) {
        final (types, yearly, closedYears) = data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(l10n.welfareYearlyAmount),
                subtitle: Text(money(context, yearly)),
                trailing: canEdit ? const Icon(Icons.edit_outlined) : null,
                onTap: canEdit ? () => _editYearly(yearly) : null,
              ),
            ),
            SectionTitle(
              l10n.welfareCaseTypes,
              trailing: canEdit ? IconButton(icon: const Icon(Icons.add), onPressed: _edit) : null,
            ),
            Text(l10n.welfareRulesHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            if (types.isEmpty) EmptyNote(l10n.welfareNoRules),
            for (final t in types) ...[
              Card(
                child: ListTile(
                  title: Text(t.name),
                  subtitle: Text([
                    if (t.description.isNotEmpty) t.description,
                    if (t.beneficiaryContributes) l10n.welfareBeneficiaryContributes,
                    if (!t.isActive) l10n.inactive,
                  ].join('\n')),
                  isThreeLine: t.description.isNotEmpty && t.beneficiaryContributes,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money(context, t.contributionPerMember), style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(l10n.welfarePerMember, style: theme.textTheme.bodySmall),
                    ],
                  ),
                  onTap: canEdit ? () => _edit(t) : null,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (session.can('welfare.close_year')) ...[
              SectionTitle(l10n.welfareYearEnd),
              Text(l10n.welfareYearEndHelp, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              closedYears.contains(lastYear)
                  ? EmptyNote(l10n.welfareYearClosed(lastYear))
                  : OutlinedButton.icon(
                      onPressed: () => _closeYear(lastYear),
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(l10n.welfareCloseYear(lastYear)),
                    ),
            ],
          ],
        );
      },
    );
  }
}

class _CaseTypeSheet extends StatefulWidget {
  final WelfareCaseType? type;
  const _CaseTypeSheet({this.type});

  @override
  State<_CaseTypeSheet> createState() => _CaseTypeSheetState();
}

class _CaseTypeSheetState extends State<_CaseTypeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.type?.name ?? '');
  late final _description = TextEditingController(text: widget.type?.description ?? '');
  late final _amount = TextEditingController(text: widget.type?.contributionPerMember.toStringAsFixed(2) ?? '');
  late bool _beneficiaryContributes = widget.type?.beneficiaryContributes ?? false;
  late bool _active = widget.type?.isActive ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().api!.saveWelfareCaseType(
            id: widget.type?.id,
            name: _name.text.trim(),
            description: _description.text.trim(),
            contributionPerMember: Money.parseUserInput(_amount.text)!,
            beneficiaryContributes: _beneficiaryContributes,
            isActive: _active,
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.type == null ? l10n.welfareAddRule : l10n.welfareEditRule,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.welfareRuleName, hintText: l10n.welfareRuleNameHint),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.welfareContributionPerMember,
                  prefixText: '${context.read<Session>().currency} ',
                ),
                validator: (v) => Money.parseUserInput(v ?? '') == null ? l10n.amountInvalid : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.welfareRuleDescription),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.welfareBeneficiaryContributes),
                value: _beneficiaryContributes,
                onChanged: (v) => setState(() => _beneficiaryContributes = v),
              ),
              if (widget.type != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.active),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.save)),
            ],
          ),
        ),
      ),
    );
  }
}
