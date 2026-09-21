import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/governance_api.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../models/governance.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/glass.dart';
import '../../widgets/inuka_app_bar.dart';
import '../meetings/meeting_papers.dart';

String meetingTypeLabel(AppLocalizations l, String type) => switch (type) {
      'AGM' => l.meetingAgm,
      'SGM' => l.meetingSgm,
      'MONTHLY' => l.meetingMonthly,
      'COMMITTEE' => l.meetingCommittee,
      'BOARD' => l.meetingBoard,
      _ => type,
    };

(String, Tone, IconData) attendanceInfo(AppLocalizations l, String? status) => switch (status) {
      'PRESENT' => (l.attPresent, Tone.good, Icons.check_circle),
      'LATE' => (l.attLate, Tone.warn, Icons.schedule),
      'APOLOGY' => (l.attApology, Tone.neutral, Icons.mail_outline),
      'ABSENT' => (l.attAbsent, Tone.bad, Icons.cancel),
      _ => (l.attNotMarked, Tone.neutral, Icons.radio_button_unchecked),
    };

String meetingWhen(BuildContext context, DateTime? at) =>
    at == null ? '—' : DateFormat('EEE d MMM y · HH:mm', Localizations.localeOf(context).toString()).format(at);

/// Secretary / chair: schedule meetings and take the register.
class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: InukaAppBar(
          title: l10n.meetingsTitle,
          bottom: TabBar(tabs: [Tab(text: l10n.meetingsUpcoming), Tab(text: l10n.meetingsPast)]),
        ),
        floatingActionButton: session.can('governance.call_meeting')
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.event),
                label: Text(l10n.meetingSchedule),
                onPressed: () async {
                  final created = await Navigator.of(context)
                      .push<bool>(MaterialPageRoute(builder: (_) => const _ScheduleMeetingScreen()));
                  if (created == true) setState(() => _version++);
                },
              )
            : null,
        body: TabBarView(children: [
          _MeetingList(key: ValueKey('up$_version'), when: 'upcoming'),
          _MeetingList(key: ValueKey('past$_version'), when: 'past'),
        ]),
      ),
    );
  }
}

class _MeetingList extends StatelessWidget {
  final String when;
  const _MeetingList({super.key, required this.when});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.read<Session>();
    return AsyncView<List<MeetingItem>>(
      load: () => session.api!.meetings(when: when),
      builder: (context, meetings, reload) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          if (meetings.isEmpty) EmptyNote(when == 'upcoming' ? l10n.meetingsNoneUpcoming : l10n.meetingsNonePast),
          for (final (i, m) in meetings.indexed) ...[
            Appear(
              index: i,
              child: _MeetingCard(
                meeting: m,
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MeetingPapersScreen(meeting: m)));
                  reload();
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingItem meeting;
  final VoidCallback? onTap;
  const _MeetingCard({required this.meeting, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final m = meeting;
    final at = m.scheduledAt;
    return GlassCard(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: m.status == 'CANCELLED'
                ? null
                : const LinearGradient(colors: [Color(0xFFE2342B), Color(0xFFF28A1E)]),
            color: m.status == 'CANCELLED' ? theme.colorScheme.outlineVariant : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text(at == null ? '' : DateFormat('MMM').format(at).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            Text(at == null ? '' : '${at.day}',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${meetingTypeLabel(l10n, m.meetingType)} · ${meetingWhen(context, at)}', style: theme.textTheme.bodySmall),
            if (m.venue.isNotEmpty) Text(m.venue, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (m.status == 'CANCELLED') StatusChip(l10n.meetingCancelled, tone: Tone.bad),
              if (m.isHeld) ...[
                StatusChip('${l10n.attPresent} ${(m.counts['PRESENT'] ?? 0) + (m.counts['LATE'] ?? 0)}', tone: Tone.good),
                StatusChip('${l10n.attApology} ${m.counts['APOLOGY'] ?? 0}'),
                StatusChip('${l10n.attAbsent} ${m.counts['ABSENT'] ?? 0}', tone: Tone.bad),
              ],
              if (m.isScheduled && (m.counts['APOLOGY'] ?? 0) > 0)
                StatusChip(l10n.meetingApologiesIn(m.counts['APOLOGY']!)),
              if (m.documentCount > 0) StatusChip(l10n.documentsCount(m.documentCount)),
              if (m.minutesStatus != null)
                Builder(builder: (context) {
                  final (text, tone) = minutesStatusInfo(context, m.minutesStatus);
                  return StatusChip(text, tone: tone);
                }),
            ]),
          ]),
        ),
        if (onTap != null) const Icon(Icons.chevron_right),
      ]),
    );
  }
}

class _ScheduleMeetingScreen extends StatefulWidget {
  const _ScheduleMeetingScreen();

  @override
  State<_ScheduleMeetingScreen> createState() => _ScheduleMeetingScreenState();
}

class _ScheduleMeetingScreenState extends State<_ScheduleMeetingScreen> {
  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _agenda = TextEditingController();
  String _type = 'MONTHLY';
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _time = const TimeOfDay(hour: 14, minute: 0);
  bool _notice = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _agenda.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_title.text.trim().isEmpty) return setState(() => _error = l10n.required);
    final at = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().api!.scheduleMeeting(
            type: _type, title: _title.text.trim(), at: at, venue: _venue.text.trim(),
            agenda: _agenda.text.trim(), sendNotice: _notice,
          );
      if (!mounted) return;
      showSnack(context, _notice ? l10n.meetingScheduledNotified : l10n.meetingScheduled);
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
    final general = const {'MONTHLY', 'AGM', 'SGM'}.contains(_type);
    return Scaffold(
      appBar: InukaAppBar(title: l10n.meetingSchedule),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: InputDecoration(labelText: l10n.meetingType),
          items: [for (final t in meetingTypes) DropdownMenuItem(value: t, child: Text(meetingTypeLabel(l10n, t)))],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        const SizedBox(height: 10),
        TextField(controller: _title, decoration: InputDecoration(labelText: l10n.meetingTitleLabel, hintText: l10n.meetingTitleHint)),
        DateField(
          label: l10n.journalDate,
          value: _date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 730)),
          onChanged: (d) => setState(() => _date = d),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(l10n.meetingTime),
          subtitle: Text(_time.format(context)),
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: _time);
            if (picked != null) setState(() => _time = picked);
          },
        ),
        TextField(controller: _venue, decoration: InputDecoration(labelText: l10n.meetingVenue)),
        const SizedBox(height: 10),
        TextField(controller: _agenda, maxLines: 4, decoration: InputDecoration(labelText: l10n.meetingAgenda)),
        if (general)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.meetingSendNotice),
            subtitle: Text(l10n.meetingSendNoticeHelp),
            value: _notice,
            onChanged: (v) => setState(() => _notice = v),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.meetingNotCounted, style: Theme.of(context).textTheme.bodySmall),
          ),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.meetingSchedule)),
      ]),
    );
  }
}

/// The attendance register: one-tap marks per member, then close.
class RegisterScreen extends StatefulWidget {
  final String meetingId;
  const RegisterScreen({super.key, required this.meetingId});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  MeetingItem? _meeting;
  List<RegisterRow>? _rows;
  String? _error;
  String _filter = '';
  bool _dirty = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<Session>().api!.meetingRegister(widget.meetingId);
      if (!mounted) return;
      setState(() {
        _meeting = r.meeting;
        _rows = r.rows;
        _error = null;
        _dirty = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    }
  }

  Future<void> _save({bool quiet = false}) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    final ok = await runAction(context, () => context.read<Session>().api!.recordAttendance(widget.meetingId, _rows!),
        done: quiet ? '' : l10n.registerSaved);
    if (mounted) setState(() => _busy = false);
    if (ok) await _load();
  }

  Future<void> _close() async {
    final l10n = context.l10n;
    final unmarked = _rows!.where((r) => r.status == null).length;
    final ok = await confirm(context,
        title: l10n.registerClose, body: l10n.registerCloseBody(unmarked), action: l10n.registerClose);
    if (!ok || !mounted) return;
    if (_dirty) await _save(quiet: true);
    if (!mounted) return;
    await runAction(context, () => context.read<Session>().api!.closeRegister(widget.meetingId), done: l10n.registerClosed);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final m = _meeting;
    final rows = _rows;
    final editable = m != null && m.status != 'CANCELLED';
    final visible = rows?.where((r) {
      final q = _filter.toLowerCase();
      return q.isEmpty || r.fullName.toLowerCase().contains(q) || r.memberNumber.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: InukaAppBar(
        title: m?.title ?? l10n.meetingsTitle,
        subtitle: m == null ? null : meetingWhen(context, m.scheduledAt),
        actions: [
          if (m != null && m.isScheduled && context.read<Session>().can('governance.call_meeting'))
            PopupMenuButton<String>(
              onSelected: (_) async {
                final ok = await confirm(context, title: l10n.meetingCancel, body: l10n.meetingCancelBody, action: l10n.meetingCancel);
                if (!ok || !context.mounted) return;
                await runAction(context, () => context.read<Session>().api!.cancelMeeting(widget.meetingId),
                    done: l10n.meetingCancelled);
                if (context.mounted) Navigator.pop(context);
              },
              itemBuilder: (_) => [PopupMenuItem(value: 'cancel', child: Text(l10n.meetingCancel))],
            ),
        ],
      ),
      bottomNavigationBar: editable && rows != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(onPressed: _busy || !_dirty ? null : _save, child: Text(l10n.save)),
                  ),
                  if (m.isScheduled) ...[
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(onPressed: _busy ? null : _close, child: Text(l10n.registerClose))),
                  ],
                ]),
              ),
            )
          : null,
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : rows == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(children: [
                      for (final s in attendanceStatuses)
                        Expanded(
                          child: Column(children: [
                            Text('${rows.where((r) => r.status == s).length}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                            Text(attendanceInfo(l10n, s).$1, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchMemberHint),
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                  ),
                  if (m!.isHeld)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(l10n.registerHeldHelp, style: theme.textTheme.bodySmall),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: visible!.length,
                      itemBuilder: (context, i) {
                        final r = visible[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(r.fullName, style: const TextStyle(fontWeight: FontWeight.w700))),
                                if (!r.isVerified) ...[
                                  Tooltip(message: l10n.probationNoVote, child: StatusChip(l10n.probation, tone: Tone.warn)),
                                  const SizedBox(width: 6),
                                ],
                                Text(r.memberNumber, style: theme.textTheme.bodySmall),
                              ]),
                              if (r.apologyReason.isNotEmpty)
                                Text(l10n.apologyReasonShown(r.apologyReason),
                                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                              const SizedBox(height: 6),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                for (final s in attendanceStatuses)
                                  ChoiceChip(
                                    avatar: Icon(attendanceInfo(l10n, s).$3, size: 16),
                                    label: Text(attendanceInfo(l10n, s).$1),
                                    selected: r.status == s,
                                    onSelected: editable
                                        ? (_) => setState(() {
                                              r.status = s;
                                              _dirty = true;
                                            })
                                        : null,
                                  ),
                              ]),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
    );
  }
}
