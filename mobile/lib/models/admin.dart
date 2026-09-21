import 'package:decimal/decimal.dart';

import '../core/money.dart';

// Shapes mirror backend accesscontrol/support_views.py, audit/serializers.py
// and members/admission_views.py.

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;
String _str(Object? value) => value?.toString() ?? '';
List<Map<String, dynamic>> _list(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

/// Someone with a login to this SACCO (admin support).
class AdminUser {
  final String id;
  final String name;
  final String phoneNumber;
  final String email;
  final String? memberId;
  final String memberNumber;
  final String memberStatus;
  final bool? memberVerified;
  final String? photo;
  final List<String> roles;
  final bool loginEnabled;
  final bool mustChangePassword;
  final DateTime? lastLogin;
  final DateTime? lastSeen;
  final List<({String device, String location, String ip})> recentDevices;
  final List<({DateTime? at, String summary, String location, String device})> recentActivity;

  AdminUser.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        name = _str(json['name']),
        phoneNumber = _str(json['phone_number']),
        email = _str(json['email']),
        memberId = json['member_id'] as String?,
        memberNumber = _str(json['member_number']),
        memberStatus = _str(json['member_status']),
        memberVerified = json['member_verified'] as bool?,
        photo = json['photo'] as String?,
        roles = ((json['roles'] as List?) ?? const []).map((r) => r.toString()).toList(),
        loginEnabled = json['login_enabled'] == true,
        mustChangePassword = json['must_change_password'] == true,
        lastLogin = _date(json['last_login']),
        lastSeen = _date(json['last_seen']),
        recentDevices = _list(json['recent_devices'])
            .map((d) => (device: _str(d['device']), location: _str(d['location']), ip: _str(d['ip_address'])))
            .toList(),
        recentActivity = _list(json['recent_activity'])
            .map((a) => (
                  at: _date(a['at']),
                  summary: _str(a['summary']),
                  location: _str(a['location']),
                  device: _str(a['device']),
                ))
            .toList();

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  /// Roles other than the automatic "Member".
  List<String> get positions => roles.where((r) => r != 'Member' && r != 'Guarantor').toList();
}

class PositionHolder {
  final String membershipId;
  final String userId;
  final String name;
  final String phoneNumber;
  final String jobTitle;
  final DateTime? assignedAt;

  PositionHolder.fromJson(Map<String, dynamic> json)
      : membershipId = _str(json['membership_id']),
        userId = _str(json['user_id']),
        name = _str(json['name']),
        phoneNumber = _str(json['phone_number']),
        jobTitle = _str(json['job_title']),
        assignedAt = _date(json['assigned_at']);
}

/// A role / office and who holds it.
class Position {
  final String id;
  final String name;
  final String description;
  final bool isPosition;
  final int? maxHolders;
  final String? assistantOf;
  final String assistantOfName;
  final int permissionCount;
  final List<PositionHolder> holders;

  Position.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        name = _str(json['name']),
        description = _str(json['description']),
        isPosition = json['is_position'] == true,
        maxHolders = (json['max_holders'] as num?)?.toInt(),
        assistantOf = json['assistant_of'] as String?,
        assistantOfName = _str(json['assistant_of_name']),
        permissionCount = (json['permission_count'] as num?)?.toInt() ?? 0,
        holders = _list(json['holders']).map(PositionHolder.fromJson).toList();

  bool get isFull => maxHolders != null && holders.length >= maxHolders!;
}

class AuditEventItem {
  final String id;
  final DateTime? at;
  final String actor;
  final String action;
  final String actionLabel;
  final String event;
  final String area;
  final String summary;
  final String method;
  final String path;
  final int? statusCode;
  final String targetLabel;
  final String ipAddress;
  final String location;
  final double? latitude;
  final double? longitude;
  final String device;
  final String userAgent;

  AuditEventItem.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        at = _date(json['at']),
        actor = _str(json['actor']),
        action = _str(json['action']),
        actionLabel = _str(json['action_label']),
        event = _str(json['event']),
        area = _str(json['area']),
        summary = _str(json['summary']),
        method = _str(json['method']),
        path = _str(json['path']),
        statusCode = (json['status_code'] as num?)?.toInt(),
        targetLabel = _str(json['target_label']),
        ipAddress = _str(json['ip_address']),
        location = _str(json['location']),
        latitude = double.tryParse(_str(json['latitude'])),
        longitude = double.tryParse(_str(json['longitude'])),
        device = _str(json['device']),
        userAgent = _str(json['user_agent']);

  bool get failed => action == 'LOGIN_FAILED' || (statusCode != null && statusCode! >= 400);
}

class MemberApplicationItem {
  final String id;
  final String status;
  final String statusLabel;
  final String fullName;
  final Map<String, dynamic> raw;
  final Decimal feeCollected;
  final String feeMethod;
  final String submittedBy;
  final String submittedByName;
  final DateTime? submittedAt;
  final String decidedByName;
  final DateTime? decidedAt;
  final String decisionNotes;
  final String? memberId;
  final String memberNumber;
  final String? temporaryPassword;

  MemberApplicationItem.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        status = _str(json['status']),
        statusLabel = _str(json['status_label']),
        fullName = _str(json['full_name']),
        raw = json,
        feeCollected = Money.parse(json['fee_collected']),
        feeMethod = _str(json['fee_method']),
        submittedBy = _str(json['submitted_by']),
        submittedByName = _str(json['submitted_by_name']),
        submittedAt = _date(json['submitted_at']),
        decidedByName = _str(json['decided_by_name']),
        decidedAt = _date(json['decided_at']),
        decisionNotes = _str(json['decision_notes']),
        memberId = json['member_id'] as String?,
        memberNumber = _str(json['member_number']),
        temporaryPassword = json['temporary_password'] as String?;

  String field(String key) => _str(raw[key]);
}

/// Probation → verified progress (members.admission.verification_status).
class Verification {
  final bool verified;
  final DateTime? verifiedAt;
  final Decimal registrationFee;
  final Decimal feePaid;
  final Decimal feeOutstanding;
  final int monthsRequired;
  final int monthsDone;

  Verification.fromJson(Map<String, dynamic> json)
      : verified = json['verified'] == true,
        verifiedAt = _date(json['verified_at']),
        registrationFee = Money.parse(json['registration_fee']),
        feePaid = Money.parse(json['fee_paid']),
        feeOutstanding = Money.parse(json['fee_outstanding']),
        monthsRequired = (json['months_required'] as num?)?.toInt() ?? 3,
        monthsDone = (json['months_done'] as num?)?.toInt() ?? 0;

  bool get feeDone => feeOutstanding <= Decimal.zero;
}

class MembershipRules {
  final Decimal registrationFee;
  final int verificationMonths;

  MembershipRules.fromJson(Map<String, dynamic> json)
      : registrationFee = Money.parse(json['registration_fee']),
        verificationMonths = (json['verification_months'] as num?)?.toInt() ?? 3;
}
