import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/governance_api.dart';
import '../../core/session.dart';
import '../../models/governance.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/glass.dart';
import '../../widgets/inuka_app_bar.dart';
import '../leader/meetings_screen.dart' show RegisterScreen, meetingWhen;
import '../profile/id_scan.dart' show pickDocumentPhoto;

const documentKinds = ['AGENDA', 'NOTICE', 'REPORT', 'FINANCIALS', 'SIGNED_MINUTES', 'ATTACHMENT'];

String documentKindLabel(BuildContext context, String kind) {
  final l = context.l10n;
  return switch (kind) {
    'AGENDA' => l.docAgenda,
    'NOTICE' => l.docNotice,
    'REPORT' => l.docReport,
    'FINANCIALS' => l.docFinancials,
    'SIGNED_MINUTES' => l.docSignedMinutes,
    _ => l.docAttachment,
  };
}

(String, Tone) minutesStatusInfo(BuildContext context, String? status) {
  final l = context.l10n;
  return switch (status) {
    'DRAFT' => (l.minutesDraft, Tone.neutral),
    'SUBMITTED' => (l.minutesAwaitingApproval, Tone.warn),
    'APPROVED' => (l.minutesApproved, Tone.good),
    _ => (l.minutesNone, Tone.neutral),
  };
}

/// Downloads a meeting file with the person's login and opens it in a
/// phone app (PDF viewer, Word, gallery...), falling back to the share sheet.
Future<void> openMeetingFile(BuildContext context, String path, String fileName) async {
  final api = context.read<Session>().api!;
  try {
    final bytes = await api.downloadBytes(path);
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(bytes);
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    }
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(context, e), error: true);
  }
}

/// A meeting's papers: documents (agenda, reports, financials...) and the
/// minutes. Leaders who take the register get a shortcut to it.
class MeetingPapersScreen extends StatelessWidget {
  final MeetingItem meeting;
  final int initialTab;
  const MeetingPapersScreen({super.key, required this.meeting, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: InukaAppBar(
          title: meeting.title,
          subtitle: meetingWhen(context, meeting.scheduledAt),
          actions: [
            if (session.can('governance.take_attendance'))
              IconButton(
                tooltip: l10n.meetingRegister,
                icon: const Icon(Icons.fact_check_outlined),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => RegisterScreen(meetingId: meeting.id))),
              ),
          ],
          bottom: TabBar(tabs: [Tab(text: l10n.meetingDocuments), Tab(text: l10n.meetingMinutes)]),
        ),
        body: TabBarView(children: [
          _DocumentsTab(meeting: meeting),
          _MinutesTab(meeting: meeting),
        ]),
      ),
    );
  }
}

class _DocumentsTab extends StatefulWidget {
  final MeetingItem meeting;
  const _DocumentsTab({required this.meeting});

  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  final _view = GlobalKey<AsyncViewState<List<MeetingDocumentItem>>>();
  bool _uploading = false;

  Future<void> _add() async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: Text(l10n.chooseFile),
            subtitle: Text(l10n.chooseFileHelp),
            onTap: () => Navigator.pop(context, 'file'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.photoOfPaper),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    String? path;
    String? name;
    if (source == 'file') {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'txt', 'csv',
          'jpg', 'jpeg', 'png', 'heic'],
      );
      if (files.isEmpty) return;
      path = files.first.path;
      name = files.first.name;
    } else {
      final photo = await pickDocumentPhoto(context);
      if (photo == null) return;
      path = photo;
      name = 'photo.jpg';
    }
    if (path == null || !mounted) return;
    final details = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _DocumentDetailsDialog(defaultTitle: name!.replaceAll(RegExp(r'\.[^.]+$'), '')),
    );
    if (details == null || !mounted) return;
    setState(() => _uploading = true);
    final ok = await runAction(
      context,
      () => context.read<Session>().api!.uploadMeetingDocument(widget.meeting.id,
          filePath: path!, fileName: name!, title: details.$1, kind: details.$2),
      done: l10n.documentAdded,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (ok) _view.currentState?.reload();
  }

  Future<void> _withdraw(MeetingDocumentItem d) async {
    final l10n = context.l10n;
    final reason = await askText(context, title: l10n.withdrawDocument, label: l10n.withdrawReason, required: true,
        message: l10n.withdrawDocumentHelp);
    if (reason == null || !mounted) return;
    if (await runAction(context, () => context.read<Session>().api!.withdrawMeetingDocument(d.id, reason),
        done: l10n.documentWithdrawn)) {
      _view.currentState?.reload();
    }
  }

  IconData _icon(MeetingDocumentItem d) {
    if (d.isPdf) return Icons.picture_as_pdf_rounded;
    if (d.isImage) return Icons.image_rounded;
    final name = d.originalName.toLowerCase();
    if (name.endsWith('.xls') || name.endsWith('.xlsx') || name.endsWith('.csv') || name.endsWith('.ods')) {
      return Icons.table_chart_rounded;
    }
    if (name.endsWith('.ppt') || name.endsWith('.pptx')) return Icons.slideshow_rounded;
    return Icons.description_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final canUpload = session.can('governance.upload_minutes');
    return Scaffold(
      floatingActionButton: canUpload && widget.meeting.status != 'CANCELLED'
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _add,
              icon: _uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.attach_file_rounded),
              label: Text(l10n.addDocument),
            )
          : null,
      body: AsyncView<List<MeetingDocumentItem>>(
        key: _view,
        load: () => session.api!.meetingDocuments(widget.meeting.id),
        builder: (context, docs, reload) {
          final theme = Theme.of(context);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
            if (widget.meeting.confidential)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l10n.confidentialPapers, style: theme.textTheme.bodySmall)),
                ]),
              ),
            if (widget.meeting.agenda.isNotEmpty) ...[
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.meetingAgenda, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(widget.meeting.agenda),
                ]),
              ),
              const SizedBox(height: 10),
            ],
            if (docs.isEmpty) EmptyNote(l10n.noDocuments),
            for (final (i, d) in docs.indexed) ...[
              Appear(
                index: i,
                child: Opacity(
                  opacity: d.withdrawn ? 0.55 : 1,
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    onTap: d.withdrawn ? null : () => openMeetingFile(context, d.downloadPath, d.originalName),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: InukaColors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_icon(d), color: InukaColors.red),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            [documentKindLabel(context, d.kind), d.sizeText, formatDate(context, d.uploadedAt)].join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (d.withdrawn)
                            Text(l10n.withdrawnBecause(d.withdrawnReason),
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                        ]),
                      ),
                      if (canUpload && !d.withdrawn)
                        PopupMenuButton<String>(
                          onSelected: (_) => _withdraw(d),
                          itemBuilder: (_) => [PopupMenuItem(value: 'withdraw', child: Text(l10n.withdrawDocument))],
                        )
                      else if (!d.withdrawn)
                        const Icon(Icons.open_in_new_rounded, size: 20),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ]);
        },
      ),
    );
  }
}


class _DocumentDetailsDialog extends StatefulWidget {
  final String defaultTitle;
  const _DocumentDetailsDialog({required this.defaultTitle});

  @override
  State<_DocumentDetailsDialog> createState() => _DocumentDetailsDialogState();
}

class _DocumentDetailsDialogState extends State<_DocumentDetailsDialog> {
  late final _title = TextEditingController(text: widget.defaultTitle);
  String _kind = 'REPORT';

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addDocument),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _title, decoration: InputDecoration(labelText: l10n.documentTitle)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _kind,
          decoration: InputDecoration(labelText: l10n.documentType),
          items: [for (final k in documentKinds) DropdownMenuItem(value: k, child: Text(documentKindLabel(context, k)))],
          onChanged: (v) => setState(() => _kind = v ?? _kind),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, (_title.text.trim(), _kind)),
          child: Text(l10n.upload),
        ),
      ],
    );
  }
}

class _MinutesTab extends StatefulWidget {
  final MeetingItem meeting;
  const _MinutesTab({required this.meeting});

  @override
  State<_MinutesTab> createState() => _MinutesTabState();
}

class _MinutesTabState extends State<_MinutesTab> {
  final _view = GlobalKey<AsyncViewState<MinutesData>>();

  Future<void> _edit(MinutesData m) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MinutesEditorScreen(meeting: widget.meeting, minutes: m)),
    );
    if (saved == true) _view.currentState?.reload();
  }

  Future<void> _act(String action, {String comment = '', String text = '', required String done}) async {
    if (await runAction(
        context,
        () => context.read<Session>().api!.minutesAction(widget.meeting.id, action, comment: comment, text: text),
        done: done)) {
      _view.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return AsyncView<MinutesData>(
      key: _view,
      load: () => session.api!.minutes(widget.meeting.id),
      builder: (context, m, reload) {
        final theme = Theme.of(context);
        final (statusText, tone) = minutesStatusInfo(context, m.exists ? m.status : null);
        final mine = m.submittedBy == session.profile?.userId;
        final visible = m.exists && (m.isApproved || m.canWrite || m.canApprove);
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.article_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.meetingMinutes, style: const TextStyle(fontWeight: FontWeight.w800))),
                StatusChip(statusText, tone: tone),
              ]),
              if (m.submittedByName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(l10n.minutesSubmittedBy(m.submittedByName, formatDate(context, m.submittedAt)),
                    style: theme.textTheme.bodySmall),
              ],
              if (m.isApproved)
                Text(l10n.minutesApprovedBy(m.approvedByName, formatDate(context, m.approvedAt)),
                    style: theme.textTheme.bodySmall),
              if (m.returnComment.isNotEmpty && m.isDraft) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(l10n.minutesSentBack(m.returnComment)),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          if (!visible && !m.canWrite)
            EmptyNote(widget.meeting.isScheduled ? l10n.minutesAfterMeeting : l10n.minutesNotYetApproved),
          if (m.canWrite && m.isDraft)
            FilledButton.icon(
              onPressed: widget.meeting.status == 'CANCELLED' ? null : () => _edit(m),
              icon: Icon(m.exists ? Icons.edit_note_rounded : Icons.post_add_rounded),
              label: Text(m.exists ? l10n.editMinutes : l10n.writeMinutes),
            ),
          if (m.canWrite && m.isDraft && m.exists) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await confirm(context,
                    title: l10n.submitMinutes, body: l10n.submitMinutesBody, action: l10n.submitMinutes);
                if (ok && context.mounted) await _act('submit', done: l10n.minutesSubmitted);
              },
              icon: const Icon(Icons.send_rounded),
              label: Text(l10n.submitMinutes),
            ),
          ],
          if (m.isSubmitted && m.canApprove) ...[
            if (mine)
              Text(l10n.cantApproveOwnMinutes, style: TextStyle(color: theme.colorScheme.error))
            else
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final comment = await askText(context,
                          title: l10n.sendBackMinutes, label: l10n.whatNeedsChanging, required: true);
                      if (comment != null && context.mounted) {
                        await _act('return', comment: comment, done: l10n.minutesReturned);
                      }
                    },
                    child: Text(l10n.sendBackMinutes),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final ok = await confirm(context,
                          title: l10n.approveMinutes, body: l10n.approveMinutesBody, action: l10n.approve);
                      if (ok && context.mounted) await _act('approve', done: l10n.minutesApproved);
                    },
                    child: Text(l10n.approveMinutes),
                  ),
                ),
              ]),
          ],
          if (m.isApproved) ...[
            Wrap(spacing: 8, runSpacing: 8, children: [
              ActionChip(
                avatar: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(l10n.minutesPdf),
                onPressed: () => openMeetingFile(context, '/api/governance/meetings/${m.meetingId}/minutes/pdf/',
                    'minutes-${widget.meeting.title}.pdf'),
              ),
              if (m.canWrite)
                ActionChip(
                  avatar: const Icon(Icons.playlist_add_rounded, size: 18),
                  label: Text(l10n.addAddendum),
                  onPressed: () async {
                    final text = await askText(context,
                        title: l10n.addAddendum, label: l10n.addendumText, required: true, message: l10n.addendumHelp);
                    if (text != null && context.mounted) await _act('addendum', text: text, done: l10n.addendumAdded);
                  },
                ),
            ]),
          ],
          if (visible) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(m.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
              ),
            ),
            for (final a in m.addenda)
              Card(
                color: InukaColors.orange.withValues(alpha: 0.12),
                child: ListTile(
                  title: Text(l10n.addendumBy(a.addedByName, formatDate(context, a.addedAt)),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(a.text),
                ),
              ),
          ],
        ]);
      },
    );
  }
}

/// Full-screen minutes editor. Starts from a template (heading, attendance,
/// one numbered minute per agenda item) the first time.
class MinutesEditorScreen extends StatefulWidget {
  final MeetingItem meeting;
  final MinutesData minutes;
  const MinutesEditorScreen({super.key, required this.meeting, required this.minutes});

  @override
  State<MinutesEditorScreen> createState() => _MinutesEditorScreenState();
}

class _MinutesEditorScreenState extends State<MinutesEditorScreen> {
  late final _body = TextEditingController(text: widget.minutes.body);
  late String _saved = widget.minutes.exists ? widget.minutes.body : '';
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<bool> _save({bool close = false}) async {
    setState(() => _busy = true);
    final ok = await runAction(context, () => context.read<Session>().api!.saveMinutes(widget.meeting.id, _body.text),
        done: context.l10n.minutesSaved);
    if (!mounted) return ok;
    setState(() {
      _busy = false;
      if (ok) _saved = _body.text;
    });
    if (ok && close) Navigator.pop(context, true);
    return ok;
  }

  void _insertMinute() {
    final month = widget.meeting.scheduledAt;
    final next = RegExp(r'^MIN\s+\d+', multiLine: true).allMatches(_body.text).length + 1;
    final mm = month == null ? '' : '${month.month.toString().padLeft(2, '0')}/${month.year}';
    final text = '\n\nMIN ${next.toString().padLeft(2, '0')}/$mm: ';
    final pos = _body.selection.isValid ? _body.selection.end : _body.text.length;
    _body.text = _body.text.replaceRange(pos, pos, text);
    _body.selection = TextSelection.collapsed(offset: pos + text.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: _body.text == _saved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final save = await confirm(context, title: l10n.unsavedMinutes, body: l10n.unsavedMinutesBody, action: l10n.save);
        if (!context.mounted) return;
        if (save) {
          await _save(close: true);
        } else {
          Navigator.pop(context, false);
        }
      },
      child: Scaffold(
        appBar: InukaAppBar(
          title: l10n.meetingMinutes,
          subtitle: widget.meeting.title,
          actions: [
            IconButton(tooltip: l10n.addMinuteItem, icon: const Icon(Icons.format_list_numbered_rounded), onPressed: _insertMinute),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _save(close: true),
              icon: const Icon(Icons.save_rounded),
              label: Text(l10n.saveDraft),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _body,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(height: 1.45),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: l10n.minutesHint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minutes waiting for this approver (from "Needs your attention").
class PendingMinutesScreen extends StatelessWidget {
  const PendingMinutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final api = context.read<Session>().api!;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.taskMinutesToApprove),
      body: AsyncView<(List<PendingMinutes>, List<MeetingItem>)>(
        load: () async {
          final r = await Future.wait([api.pendingMinutes(), api.meetings(when: 'past')]);
          return (r[0] as List<PendingMinutes>, r[1] as List<MeetingItem>);
        },
        builder: (context, data, reload) {
          final (pending, meetings) = data;
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (pending.isEmpty) EmptyNote(l10n.leaderAllClear),
            for (final p in pending)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(p.meetingTitle),
                  subtitle: Text(l10n.minutesSubmittedBy(p.submittedByName, formatDate(context, p.scheduledAt))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final meeting = meetings.where((m) => m.id == p.meetingId).firstOrNull;
                    if (meeting == null) return;
                    await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => MeetingPapersScreen(meeting: meeting, initialTab: 1)));
                    reload();
                  },
                ),
              ),
          ]);
        },
      ),
    );
  }
}
