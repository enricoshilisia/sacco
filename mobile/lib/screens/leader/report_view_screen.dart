import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/leader_api.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/leader.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import 'reports_screen.dart';
import '../../widgets/inuka_app_bar.dart';

/// Renders any report (they all share one shape) with its date controls,
/// reconciliation checks, and CSV export for auditors.
class ReportViewScreen extends StatefulWidget {
  final String reportKey;
  final String params; // as_of | period | account_period
  final bool canExport;
  final String? accountCode;
  const ReportViewScreen({
    super.key,
    required this.reportKey,
    required this.params,
    this.canExport = false,
    this.accountCode,
  });

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  late DateTime _asOf = DateTime.now();
  late DateTime _start = DateTime(DateTime.now().year, 1, 1);
  late DateTime _end = DateTime.now();
  LedgerAccount? _account;
  List<LedgerAccount>? _accounts;
  int _version = 0;
  bool _exporting = false;

  bool get _needsAccount => widget.params == 'account_period';

  @override
  void initState() {
    super.initState();
    if (_needsAccount) _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await context.read<Session>().api!.accounts();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _account = accounts.where((a) => a.code == (widget.accountCode ?? '1000')).firstOrNull ?? accounts.firstOrNull;
    });
  }

  ReportParams get _query => widget.params == 'as_of'
      ? ReportParams(asOf: _asOf)
      : ReportParams(start: _start, end: _end, accountCode: _needsAccount ? _account?.code : null);

  Future<void> _export() async {
    final l10n = context.l10n;
    setState(() => _exporting = true);
    try {
      final bytes = await context.read<Session>().api!.reportCsv(widget.reportKey, _query);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.reportKey}_${isoDate(DateTime.now())}.csv');
      await file.writeAsBytes(bytes);
      final (title, _, _) = reportInfo(l10n, widget.reportKey);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], subject: title));
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final (title, _, _) = reportInfo(l10n, widget.reportKey);
    final canExport = widget.canExport || session.can('reports.export');
    return Scaffold(
      appBar: InukaAppBar(
        title: title,
        actions: [
          if (canExport)
            IconButton(
              tooltip: l10n.reportExport,
              icon: _exporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share),
              onPressed: _exporting || (_needsAccount && _account == null) ? null : _export,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: widget.params == 'as_of'
                ? DateField(
                    label: l10n.reportAsAt,
                    value: _asOf,
                    lastDate: DateTime.now(),
                    onChanged: (d) => setState(() {
                      _asOf = d;
                      _version++;
                    }),
                  )
                : Column(children: [
                    if (_needsAccount)
                      _accounts == null
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField<LedgerAccount>(
                              initialValue: _account,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: l10n.journalAccount),
                              items: [for (final a in _accounts!) DropdownMenuItem(value: a, child: Text(a.label))],
                              onChanged: (a) => setState(() {
                                _account = a;
                                _version++;
                              }),
                            ),
                    Row(children: [
                      Expanded(
                        child: DateField(
                          label: l10n.reportFrom,
                          value: _start,
                          lastDate: DateTime.now(),
                          onChanged: (d) => setState(() {
                            _start = d;
                            _version++;
                          }),
                        ),
                      ),
                      Expanded(
                        child: DateField(
                          label: l10n.reportTo,
                          value: _end,
                          lastDate: DateTime.now(),
                          onChanged: (d) => setState(() {
                            _end = d;
                            _version++;
                          }),
                        ),
                      ),
                    ]),
                  ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _needsAccount && _account == null
                ? const Center(child: CircularProgressIndicator())
                : AsyncView<Report>(
                    key: ValueKey(_version),
                    load: () => session.api!.report(widget.reportKey, _query),
                    builder: (context, report, reload) => _ReportBody(report: report),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final Report report;
  const _ReportBody({required this.report});

  String _format(BuildContext context, String value, String kind) {
    if (value.isEmpty) return value;
    return switch (kind) {
      'money' => Money.format(Money.parse(value)),
      'percent' => '$value%',
      'date' => DateTime.tryParse(value) == null ? value : formatDate(context, DateTime.parse(value)),
      _ => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currency = context.read<Session>().currency;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(report.period, style: theme.textTheme.titleSmall),
        Text(l10n.reportGeneratedBy(report.generatedBy, currency), style: theme.textTheme.bodySmall),
        if (report.checks.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final check in report.checks)
            Card(
              color: check.ok ? theme.colorScheme.primaryContainer : theme.colorScheme.errorContainer,
              child: ListTile(
                dense: true,
                leading: Icon(check.ok ? Icons.check_circle : Icons.error_outline),
                title: Text(check.label),
                subtitle: Text(check.detail),
              ),
            ),
        ],
        if (report.summary.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: [
                for (final f in report.summary) InfoRow(f.label, _format(context, f.value, f.kind)),
              ]),
            ),
          ),
        ],
        for (final section in report.sections) ...[
          SectionTitle(section.title),
          if (section.rows.isEmpty)
            EmptyNote(l10n.reportNoRows)
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 52,
                  columnSpacing: 20,
                  columns: [
                    for (final c in section.columns) DataColumn(label: Text(c.label), numeric: c.isNumeric),
                  ],
                  rows: [
                    for (final row in section.rows)
                      DataRow(cells: [
                        for (var i = 0; i < section.columns.length; i++)
                          DataCell(Text(_format(context, i < row.length ? row[i] : '', section.columns[i].kind))),
                      ]),
                    if (section.totals != null)
                      DataRow(
                        color: WidgetStatePropertyAll(theme.colorScheme.surfaceContainerHighest),
                        cells: [
                          for (var i = 0; i < section.columns.length; i++)
                            DataCell(Text(
                              _format(context, i < section.totals!.length ? section.totals![i] : '', section.columns[i].kind),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            )),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
