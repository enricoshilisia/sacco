import 'package:decimal/decimal.dart';

import '../models/governance.dart';
import '../models/models.dart';
import 'sacco_api.dart';

/// Meetings, attendance and member-activity rules.
extension GovernanceApi on SaccoApi {
  Future<List<MeetingItem>> meetings({String? when}) async =>
      ((await client.get<Object?>('/api/governance/meetings/', query: when == null ? null : {'when': when})) as List? ??
              const [])
          .whereType<Map<String, dynamic>>()
          .map(MeetingItem.fromJson)
          .toList();

  Future<MeetingItem> scheduleMeeting({
    required String type,
    required String title,
    required DateTime at,
    required String venue,
    required String agenda,
    required bool sendNotice,
  }) async =>
      MeetingItem.fromJson(await client.post<Map<String, dynamic>>('/api/governance/meetings/', data: {
        'meeting_type': type,
        'title': title,
        'scheduled_at': at.toUtc().toIso8601String(),
        'venue': venue,
        'agenda': agenda,
        'send_notice': sendNotice,
      }));

  Future<({MeetingItem meeting, List<RegisterRow> rows})> meetingRegister(String id) async {
    final body = await client.get<Map<String, dynamic>>('/api/governance/meetings/$id/register/');
    return (
      meeting: MeetingItem.fromJson(body['meeting'] as Map<String, dynamic>),
      rows: ((body['rows'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(RegisterRow.fromJson).toList(),
    );
  }

  Future<void> recordAttendance(String meetingId, List<RegisterRow> rows) => client.post<Object?>(
        '/api/governance/meetings/$meetingId/register/',
        data: {
          'entries': [
            for (final r in rows)
              if (r.status != null) {'member': r.memberId, 'status': r.status, 'apology_reason': r.apologyReason},
          ],
        },
      );

  Future<int> closeRegister(String meetingId) async =>
      ((await client.post<Map<String, dynamic>>('/api/governance/meetings/$meetingId/close/'))['marked_absent'] as num)
          .toInt();

  Future<void> cancelMeeting(String meetingId) => client.post<Object?>('/api/governance/meetings/$meetingId/cancel/');

  Future<MeetingItem> sendApology(String meetingId, String reason) async => MeetingItem.fromJson(
      await client.post<Map<String, dynamic>>('/api/governance/meetings/$meetingId/apology/', data: {'reason': reason}));

  // --- Member activity ---------------------------------------------------------

  Future<MyActivity> myActivity() async =>
      MyActivity.fromJson(await client.get<Map<String, dynamic>>('/api/members/me/activity/'));

  Future<ActivitySettings> activitySettings() async =>
      ActivitySettings.fromJson(await client.get<Map<String, dynamic>>('/api/members/activity/settings/'));

  Future<ActivitySettings> saveActivitySettings({
    required bool contributionRule,
    required int warnMonths,
    required int limitMonths,
    required Decimal minContribution,
    required bool meetingRule,
    required int warnMeetings,
    required int limitMeetings,
  }) async =>
      ActivitySettings.fromJson(await client.patch<Map<String, dynamic>>('/api/members/activity/settings/', data: {
        'contribution_rule_enabled': contributionRule,
        'warn_after_months': warnMonths,
        'inactive_after_months': limitMonths,
        'min_monthly_contribution': minContribution.toStringAsFixed(2),
        'meeting_rule_enabled': meetingRule,
        'warn_after_meetings': warnMeetings,
        'inactive_after_meetings': limitMeetings,
      }));

  Future<({int flagged, int warned})> runActivityCheck() async {
    final r = await client.post<Map<String, dynamic>>('/api/members/activity/run/');
    return (flagged: (r['flagged'] as num).toInt(), warned: (r['warned'] as num).toInt());
  }

  Future<List<InactivityFlagItem>> inactivityFlags({String status = 'PENDING'}) async =>
      results(await client.get<Object?>('/api/members/activity/flags/', query: {'status': status}))
          .map(InactivityFlagItem.fromJson)
          .toList();

  Future<void> confirmFlag(String id, {String notes = ''}) =>
      client.post<Object?>('/api/members/activity/flags/$id/confirm/', data: {'notes': notes});

  Future<void> dismissFlag(String id, String notes) =>
      client.post<Object?>('/api/members/activity/flags/$id/dismiss/', data: {'notes': notes});

  Future<List<DormantMember>> dormantMembers() async =>
      ((await client.get<Object?>('/api/members/activity/dormant/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DormantMember.fromJson)
          .toList();

  Future<void> reactivateMember(String memberId, String reason) =>
      client.post<Object?>('/api/members/$memberId/reactivate/', data: {'reason': reason});
}
