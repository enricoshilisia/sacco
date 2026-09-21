import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/admin_api.dart';
import '../../core/session.dart';
import '../../models/admin.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/inuka_app_bar.dart';

/// The audit log: who did or looked at what, when, from where and on which
/// device. Newest first, searchable, filterable by dates; sign-ins and
/// security events only in [securityOnly] mode; one person's trail when
/// [userId] is set. CSV download for auditors (reports.export).
class AuditScreen extends StatefulWidget {
  final bool securityOnly;
  final String? userId;
  final String? userName;
  const AuditScreen({super.key, this.securityOnly = false, this.userId, this.userName});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  late bool _securityOnly = widget.securityOnly;
  DateTimeRange? _range;
  final List<AuditEventItem> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final result = await context.read<Session>().api!.auditEvents(
            page: _page,
            search: _query.text.trim(),
            userId: widget.userId,
            securityOnly: _securityOnly,
            from: _range?.start,
            to: _range?.end,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _page++;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) {
      _range = picked;
      _reload();
    }
  }

  Future<void> _export() async {
    try {
      final bytes = await context.read<Session>().api!.auditCsv(
            search: _query.text.trim(),
            userId: widget.userId,
            securityOnly: _securityOnly,
            from: _range?.start,
            to: _range?.end,
          );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/audit-log.csv');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], subject: 'Audit log'));
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return Scaffold(
      appBar: InukaAppBar(
        title: widget.securityOnly ? l10n.adminSecurity : l10n.adminAudit,
        subtitle: widget.userName,
        actions: [
          if (session.can('reports.export'))
            IconButton(tooltip: l10n.downloadCsv, icon: const Icon(Icons.download_rounded), onPressed: _export),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.auditSearchHint),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _reload);
              },
            ),
          ),
        ),
      ),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(children: [
            FilterChip(
              label: Text(l10n.auditSecurityOnly),
              selected: _securityOnly,
              onSelected: (v) {
                _securityOnly = v;
                _reload();
              },
            ),
            const SizedBox(width: 8),
            InputChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(_range == null
                  ? l10n.anyDate
                  : '${formatDate(context, _range!.start)} – ${formatDate(context, _range!.end)}'),
              onPressed: _pickRange,
              onDeleted: _range == null
                  ? null
                  : () {
                      _range = null;
                      _reload();
                    },
            ),
          ]),
        ),
        Expanded(
          child: _error != null && _items.isEmpty
              ? ErrorRetry(message: errorText(context, _error!), onRetry: _reload)
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                    itemCount: _items.length + 1,
                    itemBuilder: (context, i) {
                      if (i == _items.length) {
                        if (_loading) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _items.isEmpty ? Padding(padding: const EdgeInsets.all(24), child: EmptyNote(l10n.auditEmpty)) : const SizedBox(height: 24);
                      }
                      final showDay = i == 0 || !_sameDay(_items[i - 1].at, _items[i].at);
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (showDay)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                            child: Text(formatDate(context, _items[i].at),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                          ),
                        _EventTile(event: _items[i]),
                      ]);
                    },
                  ),
                ),
        ),
      ]),
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;
}

class _EventTile extends StatelessWidget {
  final AuditEventItem event;
  const _EventTile({required this.event});

  (IconData, Color) _look() => switch (event.action) {
        'LOGIN' => (Icons.login_rounded, InukaColors.green),
        'LOGIN_FAILED' => (Icons.gpp_bad_rounded, InukaColors.red),
        'EVENT' => (Icons.shield_rounded, InukaColors.orange),
        'VIEW' => (Icons.visibility_outlined, InukaColors.blue),
        'DELETE' => (Icons.delete_outline, InukaColors.red),
        _ => (Icons.edit_note_rounded, InukaColors.orange),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _look();
    final time = event.at == null ? '' : TimeOfDay.fromDateTime(event.at!).format(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color, size: 20)),
        title: Text(event.summary, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, color: event.failed ? theme.colorScheme.error : null)),
        subtitle: Text(
          [
            event.actor.isEmpty ? '—' : event.actor,
            [time, if (event.location.isNotEmpty) event.location].join(' · '),
            if (event.device.isNotEmpty) event.device,
          ].join('\n'),
          style: theme.textTheme.bodySmall,
        ),
        isThreeLine: true,
        onTap: () => _details(context),
      ),
    );
  }

  void _details(BuildContext context) {
    final l10n = context.l10n;
    final e = event;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(e.summary, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            InfoRow(l10n.auditWho, e.actor.isEmpty ? '—' : e.actor),
            InfoRow(l10n.auditWhen, e.at == null ? '—' : '${formatDate(context, e.at)} ${TimeOfDay.fromDateTime(e.at!).format(context)}'),
            InfoRow(l10n.auditAction, e.actionLabel),
            if (e.targetLabel.isNotEmpty) InfoRow(l10n.auditRecord, e.targetLabel),
            if (e.statusCode != null) InfoRow(l10n.auditResult, e.failed ? l10n.auditRefused(e.statusCode!) : l10n.auditOk),
            InfoRow(l10n.auditWhere, e.location.isEmpty ? '—' : e.location),
            if (e.latitude != null && e.longitude != null)
              InfoRow(l10n.auditCoordinates, '${e.latitude!.toStringAsFixed(4)}, ${e.longitude!.toStringAsFixed(4)}'),
            InfoRow(l10n.auditIp, e.ipAddress.isEmpty ? '—' : e.ipAddress),
            InfoRow(l10n.auditDevice, e.device.isEmpty ? '—' : e.device),
            if (e.path.isNotEmpty) InfoRow(l10n.auditRequest, '${e.method} ${e.path}'),
          ]),
        ),
      ),
    );
  }
}
