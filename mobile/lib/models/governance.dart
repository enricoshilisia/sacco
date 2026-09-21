import 'package:decimal/decimal.dart';

import '../core/money.dart';

// Meetings, attendance and member-activity rules.
// Mirrors backend/governance and backend/members/activity_views.py.

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
String _str(Object? v) => v?.toString() ?? '';

const meetingTypes = ['MONTHLY', 'AGM', 'SGM', 'COMMITTEE', 'BOARD'];
const attendanceStatuses = ['PRESENT', 'LATE', 'APOLOGY', 'ABSENT'];

class MeetingItem {
  final String id;
  final String meetingType;
  final String meetingTypeLabel;
  final String title;
  final DateTime? scheduledAt;
  final String venue;
  final String agenda;
  final bool countsForAttendance;
  final String status; // SCHEDULED / HELD / CANCELLED
  final Map<String, int> counts;
  final String? myStatus;
  final String myApologyReason;
  final int documentCount;
  final String? minutesStatus; // DRAFT / SUBMITTED / APPROVED, null = none yet
  final bool confidential; // committee/board: leaders only

  MeetingItem.fromJson(Map<String, dynamic> j)
      : documentCount = (j['document_count'] as num?)?.toInt() ?? 0,
        minutesStatus = j['minutes_status'] as String?,
        confidential = j['confidential'] == true,
        id = _str(j['id']),
        meetingType = _str(j['meeting_type']),
        meetingTypeLabel = _str(j['meeting_type_label']),
        title = _str(j['title']),
        scheduledAt = _date(j['scheduled_at']),
        venue = _str(j['venue']),
        agenda = _str(j['agenda']),
        countsForAttendance = j['counts_for_attendance'] == true,
        status = _str(j['status']),
        counts = ((j['counts'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        myStatus = (j['my_attendance'] as Map?)?['status'] as String?,
        myApologyReason = _str((j['my_attendance'] as Map?)?['apology_reason']);

  bool get isScheduled => status == 'SCHEDULED';
  bool get isHeld => status == 'HELD';
}

class RegisterRow {
  final String memberId;
  final String memberNumber;
  final String fullName;
  String? status;
  final String apologyReason;
  /// New members on probation attend but can't vote.
  final bool isVerified;

  RegisterRow.fromJson(Map<String, dynamic> j)
      : isVerified = j['is_verified'] != false,
        memberId = _str(j['member_id']),
        memberNumber = _str(j['member_number']),
        fullName = _str(j['full_name']),
        status = j['status'] as String?,
        apologyReason = _str(j['apology_reason']);
}

class ActivitySettings {
  final bool contributionRuleEnabled;
  final int warnAfterMonths;
  final int inactiveAfterMonths;
  final Decimal minMonthlyContribution;
  final bool meetingRuleEnabled;
  final int warnAfterMeetings;
  final int inactiveAfterMeetings;
  final DateTime? lastRunAt;

  ActivitySettings.fromJson(Map<String, dynamic> j)
      : contributionRuleEnabled = j['contribution_rule_enabled'] != false,
        warnAfterMonths = (j['warn_after_months'] as num?)?.toInt() ?? 2,
        inactiveAfterMonths = (j['inactive_after_months'] as num?)?.toInt() ?? 3,
        minMonthlyContribution = Money.parse(j['min_monthly_contribution']),
        meetingRuleEnabled = j['meeting_rule_enabled'] != false,
        warnAfterMeetings = (j['warn_after_meetings'] as num?)?.toInt() ?? 2,
        inactiveAfterMeetings = (j['inactive_after_meetings'] as num?)?.toInt() ?? 3,
        lastRunAt = _date(j['last_run_at']);
}

class InactivityFlagItem {
  final String id;
  final String memberId;
  final String memberNumber;
  final String memberName;
  final String memberPhone;
  final String reason; // CONTRIBUTIONS / MEETINGS
  final String detail;
  final String status;
  final DateTime? createdAt;
  final String decidedBy;
  final String notes;

  InactivityFlagItem.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        memberId = _str(j['member_id']),
        memberNumber = _str(j['member_number']),
        memberName = _str(j['member_name']),
        memberPhone = _str(j['member_phone']),
        reason = _str(j['reason']),
        detail = _str(j['detail']),
        status = _str(j['status']),
        createdAt = _date(j['created_at']),
        decidedBy = _str(j['decided_by_name']),
        notes = _str(j['notes']);
}

class DormantMember {
  final String memberId;
  final String memberNumber;
  final String memberName;
  final DateTime? since;
  final String reason;

  DormantMember.fromJson(Map<String, dynamic> j)
      : memberId = _str(j['member_id']),
        memberNumber = _str(j['member_number']),
        memberName = _str(j['member_name']),
        since = _date(j['since']),
        reason = _str(j['reason']);
}

/// GET /api/members/me/activity/
class MyActivity {
  final String status;
  final int missedMonths;
  final int? inactiveAfterMonths;
  final int missedMeetings;
  final int? inactiveAfterMeetings;

  MyActivity.fromJson(Map<String, dynamic> j)
      : status = _str(j['status']),
        missedMonths = (j['missed_months'] as num?)?.toInt() ?? 0,
        inactiveAfterMonths = (j['inactive_after_months'] as num?)?.toInt(),
        missedMeetings = (j['missed_meetings'] as num?)?.toInt() ?? 0,
        inactiveAfterMeetings = (j['inactive_after_meetings'] as num?)?.toInt();

  bool get isDormant => status == 'DORMANT';

  /// One step (or less) from a limit - worth a gentle warning.
  bool get atRisk =>
      !isDormant &&
      ((inactiveAfterMonths != null && missedMonths >= inactiveAfterMonths! - 1 && missedMonths > 0) ||
          (inactiveAfterMeetings != null && missedMeetings >= inactiveAfterMeetings! - 1 && missedMeetings > 0));
}


class MeetingDocumentItem {
  final String id;
  final String kind;
  final String kindLabel;
  final String title;
  final String originalName;
  final String contentType;
  final int size;
  final String uploadedByName;
  final DateTime? uploadedAt;
  final bool withdrawn;
  final String withdrawnReason;
  final String downloadPath;

  MeetingDocumentItem.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        kind = _str(j['kind']),
        kindLabel = _str(j['kind_label']),
        title = _str(j['title']),
        originalName = _str(j['original_name']),
        contentType = _str(j['content_type']),
        size = (j['size'] as num?)?.toInt() ?? 0,
        uploadedByName = _str(j['uploaded_by_name']),
        uploadedAt = _date(j['uploaded_at']),
        withdrawn = j['withdrawn'] == true,
        withdrawnReason = _str(j['withdrawn_reason']),
        downloadPath = _str(j['download_path']);

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf';

  String get sizeText {
    if (size >= 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (size >= 1024) return '${(size / 1024).round()} KB';
    return '$size B';
  }
}

class MinutesAddendumItem {
  final String text;
  final String addedByName;
  final DateTime? addedAt;
  MinutesAddendumItem.fromJson(Map<String, dynamic> j)
      : text = _str(j['text']),
        addedByName = _str(j['added_by_name']),
        addedAt = _date(j['added_at']);
}

class MinutesData {
  final String meetingId;
  final String meetingTitle;
  final bool exists;
  final String? status; // DRAFT / SUBMITTED / APPROVED
  final String body;
  final String returnComment;
  final String submittedBy;
  final String submittedByName;
  final DateTime? submittedAt;
  final String approvedByName;
  final DateTime? approvedAt;
  final bool canWrite;
  final bool canApprove;
  final bool confidential;
  final List<MinutesAddendumItem> addenda;

  MinutesData.fromJson(Map<String, dynamic> j)
      : meetingId = _str(j['meeting']),
        meetingTitle = _str(j['meeting_title']),
        exists = j['exists'] == true,
        status = j['status'] as String?,
        body = _str(j['body']),
        returnComment = _str(j['return_comment']),
        submittedBy = _str(j['submitted_by']),
        submittedByName = _str(j['submitted_by_name']),
        submittedAt = _date(j['submitted_at']),
        approvedByName = _str(j['approved_by_name']),
        approvedAt = _date(j['approved_at']),
        canWrite = j['can_write'] == true,
        canApprove = j['can_approve'] == true,
        confidential = j['confidential'] == true,
        addenda = ((j['addenda'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MinutesAddendumItem.fromJson)
            .toList();

  bool get isDraft => !exists || status == 'DRAFT';
  bool get isSubmitted => status == 'SUBMITTED';
  bool get isApproved => status == 'APPROVED';
}

class PendingMinutes {
  final String meetingId;
  final String meetingTitle;
  final DateTime? scheduledAt;
  final String submittedByName;
  final bool mine;
  PendingMinutes.fromJson(Map<String, dynamic> j)
      : meetingId = _str(j['meeting']),
        meetingTitle = _str(j['meeting_title']),
        scheduledAt = _date(j['scheduled_at']),
        submittedByName = _str(j['submitted_by_name']),
        mine = j['mine'] == true;
}
