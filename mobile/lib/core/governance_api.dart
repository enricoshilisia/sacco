import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../models/governance.dart';
import '../models/models.dart';
import 'api_client.dart';
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

  // --- Meeting documents & minutes ---------------------------------------------

  Future<List<MeetingDocumentItem>> meetingDocuments(String meetingId) async =>
      ((await client.get<Object?>('/api/governance/meetings/$meetingId/documents/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MeetingDocumentItem.fromJson)
          .toList();

  Future<MeetingDocumentItem> uploadMeetingDocument(
    String meetingId, {
    required String filePath,
    required String fileName,
    required String title,
    required String kind,
  }) async =>
      MeetingDocumentItem.fromJson(await client.post<Map<String, dynamic>>(
        '/api/governance/meetings/$meetingId/documents/',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath, filename: fileName),
          'title': title,
          'kind': kind,
        }),
      ));

  Future<void> withdrawMeetingDocument(String id, String reason) =>
      client.post<Object?>('/api/governance/documents/$id/withdraw/', data: {'reason': reason});

  /// Files are fetched with the person's login - never from a public link.
  Future<Uint8List> downloadBytes(String path) async {
    try {
      final response = await client.dio.get<List<int>>(path, options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(response.data ?? const []);
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<MinutesData> minutes(String meetingId) async =>
      MinutesData.fromJson(await client.get<Map<String, dynamic>>('/api/governance/meetings/$meetingId/minutes/'));

  Future<MinutesData> saveMinutes(String meetingId, String body) async {
    try {
      final r = await client.dio.put<Map<String, dynamic>>('/api/governance/meetings/$meetingId/minutes/',
          data: {'body': body});
      return MinutesData.fromJson(r.data!);
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// action: submit / approve / return / addendum
  Future<MinutesData> minutesAction(String meetingId, String action, {String comment = '', String text = ''}) async =>
      MinutesData.fromJson(await client.post<Map<String, dynamic>>(
        '/api/governance/meetings/$meetingId/minutes/$action/',
        data: {'comment': comment, 'text': text},
      ));

  Future<List<PendingMinutes>> pendingMinutes() async =>
      ((await client.get<Object?>('/api/governance/minutes/pending/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PendingMinutes.fromJson)
          .toList();

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
