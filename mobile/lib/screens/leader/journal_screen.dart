import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/leader_api.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/leader.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/inuka_app_bar.dart';

/// The journal, newest first, loaded a page at a time. Entries are never
/// edited or deleted - a mistake is corrected with a reversing entry.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _entries = <JournalEntryItem>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _reload() async {
    setState(() {
      _entries.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<Session>().api!.journal(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _entries.addAll(result.items);
        _page++;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return Scaffold(
      appBar: InukaAppBar(title: l10n.financeJournal),
      floatingActionButton: session.can('accounting.post_journal')
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(l10n.financeNewEntry),
              onPressed: () async {
                final posted = await Navigator.of(context)
                    .push<bool>(MaterialPageRoute(builder: (_) => const NewJournalEntryScreen()));
                if (posted == true) _reload();
              },
            )
          : null,
      body: _error != null && _entries.isEmpty
          ? ErrorRetry(message: _error!, onRetry: _loadMore)
          : RefreshIndicator(
              onRefresh: _reload,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _loadMore();
                  return false;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: _entries.length + 1,
                  itemBuilder: (context, i) {
                    if (i == _entries.length) {
                      return _loading
                          ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                          : _entries.isEmpty
                              ? EmptyNote(l10n.noTransactions)
                              : const SizedBox(height: 16);
                    }
                    final e = _entries[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          title: Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text([
                            e.reference,
                            formatDate(context, e.entryDate),
                            if (e.createdBy.isNotEmpty) e.createdBy,
                            if (e.reversedByReference.isNotEmpty) l10n.journalReversedBy(e.reversedByReference),
                            if (e.reversesReference.isNotEmpty) l10n.journalReverses(e.reversesReference),
                          ].join(' · ')),
                          trailing: Text(money(context, e.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                          onTap: () async {
                            final changed = await Navigator.of(context)
                                .push<bool>(MaterialPageRoute(builder: (_) => _JournalEntryScreen(entry: e)));
                            if (changed == true) _reload();
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}

class _JournalEntryScreen extends StatelessWidget {
  final JournalEntryItem entry;
  const _JournalEntryScreen({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: InukaAppBar(title: entry.reference),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(entry.description, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          InfoRow(l10n.journalDate, formatDate(context, entry.entryDate)),
          if (entry.createdBy.isNotEmpty) InfoRow(l10n.journalPostedBy, entry.createdBy),
          if (entry.reversesReference.isNotEmpty) InfoRow(l10n.journalReversesLabel, entry.reversesReference),
          if (entry.reversedByReference.isNotEmpty) InfoRow(l10n.journalReversedByLabel, entry.reversedByReference),
          SectionTitle(l10n.journalLines),
          Card(
            child: Column(children: [
              for (final line in entry.lines)
                ListTile(
                  dense: true,
                  title: Text('${line.accountCode} · ${line.accountName}'),
                  subtitle: Text([if (line.memberName.isNotEmpty) line.memberName, if (line.description.isNotEmpty) line.description]
                      .join(' · ')),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (line.debit > Decimal.zero) Text('${l10n.debitShort} ${Money.format(line.debit)}'),
                      if (line.credit > Decimal.zero) Text('${l10n.creditShort} ${Money.format(line.credit)}'),
                    ],
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 24),
          if (entry.canBeReversed && session.can('accounting.reverse_journal'))
            OutlinedButton.icon(
              icon: const Icon(Icons.undo),
              label: Text(l10n.journalReverse),
              onPressed: () async {
                final reason = await askText(context,
                    title: l10n.journalReverseTitle, label: l10n.welfareReason, required: true, message: l10n.journalReverseHelp);
                if (reason == null || !context.mounted) return;
                final ok = await runAction(context, () => session.api!.reverseJournal(entry.id, reason), done: l10n.journalReversed);
                if (ok && context.mounted) Navigator.pop(context, true);
              },
            ),
        ],
      ),
    );
  }
}

class _LineDraft {
  LedgerAccount? account;
  final debit = TextEditingController();
  final credit = TextEditingController();
  final memo = TextEditingController();

  Decimal get debitValue => Money.parseUserInput(debit.text) ?? Decimal.zero;
  Decimal get creditValue => Money.parseUserInput(credit.text) ?? Decimal.zero;

  void dispose() {
    debit.dispose();
    credit.dispose();
    memo.dispose();
  }
}

/// A manual journal entry (expenses, fees, bank charges...). Must balance;
/// member control accounts aren't offered - those move only through their
/// own modules so member balances always reconcile.
class NewJournalEntryScreen extends StatefulWidget {
  const NewJournalEntryScreen({super.key});

  @override
  State<NewJournalEntryScreen> createState() => _NewJournalEntryScreenState();
}

class _NewJournalEntryScreenState extends State<NewJournalEntryScreen> {
  final _description = TextEditingController();
  final _lines = [_LineDraft(), _LineDraft()];
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Decimal get _totalDebit => Money.sum(_lines.map((l) => l.debitValue));
  Decimal get _totalCredit => Money.sum(_lines.map((l) => l.creditValue));

  Future<void> _post() async {
    final l10n = context.l10n;
    final filled = _lines.where((l) => l.account != null && (l.debitValue > Decimal.zero || l.creditValue > Decimal.zero)).toList();
    if (_description.text.trim().isEmpty) return setState(() => _error = l10n.journalNeedsDescription);
    if (filled.length < 2) return setState(() => _error = l10n.journalNeedsTwoLines);
    if (filled.any((l) => l.debitValue > Decimal.zero && l.creditValue > Decimal.zero)) {
      return setState(() => _error = l10n.journalOneSidePerLine);
    }
    if (_totalDebit != _totalCredit) return setState(() => _error = l10n.journalNotBalanced);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().api!.postJournal(
            description: _description.text.trim(),
            date: _date,
            lines: [
              for (final l in filled)
                (accountId: l.account!.id, debit: l.debitValue, credit: l.creditValue, memo: l.memo.text.trim()),
            ],
          );
      if (!mounted) return;
      showSnack(context, l10n.journalPosted);
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
    final theme = Theme.of(context);
    final balanced = _totalDebit == _totalCredit && _totalDebit > Decimal.zero;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.financeNewEntry),
      body: AsyncView<List<LedgerAccount>>(
        load: () => context.read<Session>().api!.accounts(),
        builder: (context, accounts, reload) {
          final usable = accounts.where((a) => a.isActive && !a.isControl).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(controller: _description, decoration: InputDecoration(labelText: l10n.journalDescription)),
              DateField(label: l10n.journalDate, value: _date, onChanged: (d) => setState(() => _date = d)),
              Text(l10n.journalControlHelp, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              for (var i = 0; i < _lines.length; i++) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<LedgerAccount>(
                            initialValue: _lines[i].account,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: l10n.journalAccount),
                            items: [for (final a in usable) DropdownMenuItem(value: a, child: Text(a.label))],
                            onChanged: (a) => setState(() => _lines[i].account = a),
                          ),
                        ),
                        if (_lines.length > 2)
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() => _lines.removeAt(i).dispose()),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _lines[i].debit,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(labelText: l10n.debit),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lines[i].credit,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(labelText: l10n.credit),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      TextField(controller: _lines[i].memo, decoration: InputDecoration(labelText: l10n.journalMemo)),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextButton.icon(
                onPressed: () => setState(() => _lines.add(_LineDraft())),
                icon: const Icon(Icons.add),
                label: Text(l10n.journalAddLine),
              ),
              Card(
                color: balanced ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    InfoRow(l10n.debit, money(context, _totalDebit)),
                    InfoRow(l10n.credit, money(context, _totalCredit)),
                    InfoRow(l10n.journalDifference, money(context, _totalDebit - _totalCredit)),
                  ]),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _busy ? null : _post, child: Text(l10n.journalPost)),
            ],
          );
        },
      ),
    );
  }
}

/// Chart of accounts. Holders of accounting.manage_chart can add accounts,
/// e.g. a new expense line.
class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> {
  final _view = GlobalKey<AsyncViewState<List<LedgerAccount>>>();

  Future<void> _add() async {
    final l10n = context.l10n;
    final code = TextEditingController();
    final name = TextEditingController();
    var type = 'EXPENSE';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.chartAdd),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: code, decoration: InputDecoration(labelText: l10n.chartCode, hintText: '6200')),
            const SizedBox(height: 8),
            TextField(controller: name, decoration: InputDecoration(labelText: l10n.chartName, hintText: l10n.chartNameHint)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: InputDecoration(labelText: l10n.chartType),
              items: [
                for (final t in const ['ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE'])
                  DropdownMenuItem(value: t, child: Text(accountTypeLabel(context, t))),
              ],
              onChanged: (v) => setState(() => type = v ?? type),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.add)),
          ],
        ),
      ),
    );
    if (ok == true && mounted && code.text.trim().isNotEmpty && name.text.trim().isNotEmpty) {
      final added = await runAction(
        context,
        () => context.read<Session>().api!.createAccount(code: code.text.trim(), name: name.text.trim(), type: type),
        done: l10n.chartAdded,
      );
      if (added) _view.currentState?.reload();
    }
    code.dispose();
    name.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return Scaffold(
      appBar: InukaAppBar(title: l10n.financeChart),
      floatingActionButton: session.can('accounting.manage_chart')
          ? FloatingActionButton(onPressed: _add, child: const Icon(Icons.add))
          : null,
      body: AsyncView<List<LedgerAccount>>(
        key: _view,
        load: () => session.api!.accounts(),
        builder: (context, accounts, reload) {
          final types = const ['ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE'];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              for (final t in types) ...[
                SectionTitle(accountTypeLabel(context, t)),
                Card(
                  child: Column(children: [
                    for (final a in accounts.where((a) => a.accountType == t))
                      ListTile(
                        dense: true,
                        title: Text(a.label),
                        subtitle: a.isControl ? Text(l10n.chartControl) : null,
                        trailing: a.isActive ? null : Text(l10n.inactive),
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
}

String accountTypeLabel(BuildContext context, String type) {
  final l10n = context.l10n;
  return switch (type) {
    'ASSET' => l10n.typeAsset,
    'LIABILITY' => l10n.typeLiability,
    'EQUITY' => l10n.typeEquity,
    'INCOME' => l10n.typeIncome,
    'EXPENSE' => l10n.typeExpense,
    _ => type,
  };
}
