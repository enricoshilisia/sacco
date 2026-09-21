import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/governance_api.dart';
import '../core/session.dart';
import '../models/governance.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';
import '../widgets/glass.dart';
import '../widgets/inuka_app_bar.dart';
import 'meetings/meeting_papers.dart';
import 'leader/meetings_screen.dart';

/// A member's meetings: what's coming (with "send apology") and their own
/// attendance record.
class MyMeetingsScreen extends StatelessWidget {
  const MyMeetingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final api = context.read<Session>().api!;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.meetingsTitle),
      body: AsyncView<(List<MeetingItem>, List<MeetingItem>, MyActivity)>(
        load: () async {
          final r = await Future.wait([api.meetings(when: 'upcoming'), api.meetings(when: 'past'), api.myActivity()]);
          return (r[0] as List<MeetingItem>, r[1] as List<MeetingItem>, r[2] as MyActivity);
        },
        builder: (context, data, reload) {
          final (upcoming, past, standing) = data;
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (standing.inactiveAfterMeetings != null && standing.missedMeetings > 0)
                Card(
                  color: standing.atRisk ? theme.colorScheme.errorContainer : null,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber),
                    title: Text(l10n.missedMeetingsStreak(standing.missedMeetings, standing.inactiveAfterMeetings!)),
                    subtitle: Text(l10n.missedMeetingsHelp),
                  ),
                ),
              SectionTitle(l10n.meetingsUpcoming),
              if (upcoming.isEmpty) EmptyNote(l10n.meetingsNoneUpcoming),
              for (final m in upcoming) ...[
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text('${meetingTypeLabel(l10n, m.meetingType)} · ${meetingWhen(context, m.scheduledAt)}'),
                    if (m.venue.isNotEmpty) Text(m.venue, style: theme.textTheme.bodySmall),
                    if (m.agenda.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(m.agenda, style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 10),
                    if (m.documentCount > 0 && !m.confidential) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.folder_open_rounded),
                        label: Text(l10n.documentsCount(m.documentCount)),
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => MeetingPapersScreen(meeting: m))),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (m.myStatus == 'APOLOGY')
                      StatusChip(l10n.apologySent, tone: Tone.good)
                    else if (m.countsForAttendance)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.mail_outline),
                        label: Text(l10n.sendApology),
                        onPressed: () async {
                          final reason = await askText(context,
                              title: l10n.sendApology, label: l10n.apologyReason, required: true, message: l10n.apologyHelp);
                          if (reason == null || !context.mounted) return;
                          if (await runAction(context, () => api.sendApology(m.id, reason), done: l10n.apologySent)) {
                            await reload();
                          }
                        },
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
              SectionTitle(l10n.myAttendance),
              if (past.isEmpty) EmptyNote(l10n.meetingsNonePast),
              Card(
                child: Column(children: [
                  for (final m in past.where((m) => m.isHeld))
                    ListTile(
                      dense: true,
                      title: Text(m.title),
                      subtitle: Text([
                        meetingWhen(context, m.scheduledAt),
                        if (m.minutesStatus == 'APPROVED') l10n.minutesAvailable,
                        if (m.documentCount > 0) l10n.documentsCount(m.documentCount),
                      ].join(' · ')),
                      onTap: m.confidential
                          ? null
                          : () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => MeetingPapersScreen(meeting: m))),
                      trailing: Builder(builder: (context) {
                        final (label, tone, _) = attendanceInfo(l10n, m.myStatus);
                        return StatusChip(label, tone: tone);
                      }),
                    ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
