import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/profile_api.dart';
import '../../core/session.dart';
import '../../models/profile.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/glass.dart';
import '../../widgets/inuka_app_bar.dart';
import '../profile/document_view.dart';
import '../profile/profile_labels.dart';

/// The Secretary's queue: members' profile and family changes awaiting approval.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  String _status = 'PENDING';
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final api = context.read<Session>().api!;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.approvalsTitle),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'PENDING', label: Text(l10n.statusAwaitingApproval)),
              ButtonSegment(value: 'APPROVED', label: Text(l10n.statusApproved)),
              ButtonSegment(value: 'REJECTED', label: Text(l10n.statusRejected)),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        Expanded(
          child: AsyncView<List<ChangeRequestItem>>(
            key: ValueKey('$_status$_version'),
            load: () => api.changeRequests(status: _status),
            builder: (context, items, reload) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (items.isEmpty) EmptyNote(_status == 'PENDING' ? l10n.approvalsEmpty : l10n.reportNoRows),
                for (final (i, r) in items.indexed) ...[
                  Appear(
                    index: i,
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(_icon(r.target), color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                        title: Text('${r.memberName} · ${r.memberNumber}'),
                        subtitle: Text([
                          r.target == 'PROFILE' && r.changes.isEmpty ? l10n.firstProfileApproval : r.targetLabel,
                          if (r.familyMember != null) r.familyMember!.fullName,
                          formatDate(context, r.submittedAt),
                        ].join(' · ')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => _RequestScreen(request: r)));
                          setState(() => _version++);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }

  IconData _icon(String target) => switch (target) {
        'FAMILY_ADD' => Icons.person_add_alt_1,
        'FAMILY_UPDATE' => Icons.manage_accounts_outlined,
        'FAMILY_REMOVE' => Icons.person_remove_outlined,
        _ => Icons.badge_outlined,
      };
}

class _RequestScreen extends StatefulWidget {
  final ChangeRequestItem request;
  const _RequestScreen({required this.request});

  @override
  State<_RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<_RequestScreen> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    final l10n = context.l10n;
    final api = context.read<Session>().api!;
    final notes = await askText(
      context,
      title: approve ? l10n.approve : l10n.reject,
      label: approve ? l10n.welfareNotesOptional : l10n.rejectReasonForMember,
      required: !approve,
    );
    if (notes == null || !mounted) return;
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => approve ? api.approveChangeRequest(widget.request.id, notes: notes) : api.rejectChangeRequest(widget.request.id, notes),
      done: approve ? l10n.changeApproved : l10n.changeRejected,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final r = widget.request;
    final firstApproval = r.target == 'PROFILE' && r.changes.isEmpty;

    // Rows of (field, before, after) for the comparison table.
    final rows = <(String, Object?, Object?)>[];
    if (r.target == 'PROFILE') {
      if (firstApproval) {
        for (final e in r.current.entries) {
          rows.add((e.key, null, e.value));
        }
      } else {
        for (final e in r.changes.entries) {
          rows.add((e.key, r.before[e.key], e.value));
        }
      }
    } else if (r.target == 'FAMILY_ADD') {
      for (final e in r.changes.entries) {
        rows.add((e.key, null, e.value));
      }
    } else if (r.target == 'FAMILY_UPDATE') {
      for (final e in r.changes.entries) {
        rows.add((e.key, r.before[e.key], e.value));
      }
    }

    return Scaffold(
      appBar: InukaAppBar(title: r.targetLabel, subtitle: '${r.memberName} · ${r.memberNumber}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(firstApproval ? l10n.firstProfileApproval : r.targetLabel,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (r.familyMember != null)
              Text('${r.familyMember!.fullName} · ${relationshipLabel(l10n, r.familyMember!.relationship)}'),
            if (r.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l10n.memberSays(r.note), style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (r.target == 'FAMILY_REMOVE') ...[
              const SizedBox(height: 8),
              Text(l10n.removalWarning, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ]),
        ),
        if (rows.isNotEmpty) ...[
          SectionTitle(l10n.whatChanges),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Table(
              columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.2)},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                  children: [
                    _cell(l10n.field, bold: true),
                    _cell(firstApproval || r.target == 'FAMILY_ADD' ? '' : l10n.now, bold: true),
                    _cell(firstApproval || r.target == 'FAMILY_ADD' ? l10n.onRecord : l10n.newValue, bold: true),
                  ],
                ),
                for (final (i, row) in rows.indexed)
                  TableRow(
                    decoration: BoxDecoration(color: i.isOdd ? theme.colorScheme.onSurface.withValues(alpha: 0.03) : null),
                    children: [
                      _cell(fieldLabel(l10n, row.$1)),
                      _cell(row.$2 == null ? '' : fieldValue(l10n, row.$1, row.$2), muted: true),
                      _cell(fieldValue(l10n, row.$1, row.$3), bold: row.$2 != null),
                    ],
                  ),
              ],
            ),
          ),
        ],
        SectionTitle(l10n.documentsToCheck),
        if (r.documents.isEmpty)
          EmptyNote(l10n.noDocumentsYet)
        else
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: r.documents.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => DocumentThumb(doc: r.documents[i]),
            ),
          ),
        if (r.documents.any((d) => d.documentType == 'ID_FRONT'))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.compareIdHelp, style: theme.textTheme.bodySmall),
          ),
        const SizedBox(height: 24),
        if (r.isPending) ...[
          FilledButton.icon(
            onPressed: _busy ? null : () => _decide(true),
            icon: const Icon(Icons.check),
            label: Text(l10n.approve),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _decide(false),
            icon: const Icon(Icons.close),
            label: Text(l10n.reject),
          ),
        ] else
          Card(
            child: ListTile(
              leading: Icon(r.status == 'APPROVED' ? Icons.check_circle : Icons.cancel,
                  color: r.status == 'APPROVED' ? theme.colorScheme.tertiary : theme.colorScheme.error),
              title: Text(r.statusLabel),
              subtitle: Text([if (r.decidedBy.isNotEmpty) r.decidedBy, if (r.decisionNotes.isNotEmpty) r.decisionNotes].join(' · ')),
            ),
          ),
      ]),
    );
  }

  Widget _cell(String text, {bool bold = false, bool muted = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: muted ? Theme.of(context).colorScheme.onSurfaceVariant : null,
            decoration: muted && text.isNotEmpty ? TextDecoration.lineThrough : null,
          ),
        ),
      );
}
