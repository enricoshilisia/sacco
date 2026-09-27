import 'package:decimal/decimal.dart';

import '../core/money.dart';

// Mirrors backend/fines/views.py.

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
String _str(Object? v) => v?.toString() ?? '';
List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

class OffenceTypeItem {
  final String id;
  final String name;
  final Decimal amount;
  final String description;
  final String fromAttendance; // ABSENT / LATE / ''
  final bool isActive;

  OffenceTypeItem.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        name = _str(j['name']),
        amount = Money.parse(j['amount']),
        description = _str(j['description']),
        fromAttendance = _str(j['from_attendance']),
        isActive = j['is_active'] != false;
}

class FineItem {
  final String id;
  final String memberId;
  final String memberName;
  final String memberNumber;
  final String offence;
  final Decimal amount;
  final Decimal paid;
  final Decimal outstanding;
  final String status; // OUTSTANDING / PAID / WAIVED
  final String statusLabel;
  final DateTime? incurredOn;
  final String meetingTitle;
  final String notes;
  final String chargedByName;
  final String waivedByName;
  final String waivedReason;

  FineItem.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        memberId = _str(j['member']),
        memberName = _str(j['member_name']),
        memberNumber = _str(j['member_number']),
        offence = _str(j['offence']),
        amount = Money.parse(j['amount']),
        paid = Money.parse(j['paid']),
        outstanding = Money.parse(j['outstanding']),
        status = _str(j['status']),
        statusLabel = _str(j['status_label']),
        incurredOn = _date(j['incurred_on']),
        meetingTitle = _str(j['meeting_title']),
        notes = _str(j['notes']),
        chargedByName = _str(j['charged_by_name']),
        waivedByName = _str(j['waived_by_name']),
        waivedReason = _str(j['waived_reason']);

  bool get isOutstanding => status == 'OUTSTANDING';
  bool get isWaived => status == 'WAIVED';
}

/// One member's fines with their totals.
class MemberFines {
  final String memberId;
  final String memberName;
  final String memberNumber;
  final Decimal charged;
  final Decimal paid;
  final Decimal outstanding;
  final int countOutstanding;
  final List<FineItem> fines;

  MemberFines.fromJson(Map<String, dynamic> j)
      : memberId = _str(j['member']),
        memberName = _str(j['member_name']),
        memberNumber = _str(j['member_number']),
        charged = Money.parse(j['charged']),
        paid = Money.parse(j['paid']),
        outstanding = Money.parse(j['outstanding']),
        countOutstanding = (j['count_outstanding'] as num?)?.toInt() ?? 0,
        fines = _list(j['fines']).map(FineItem.fromJson).toList();
}

class FinesRow {
  final String memberId;
  final String memberNumber;
  final String memberName;
  final Decimal charged;
  final Decimal paid;
  final Decimal outstanding;
  final int count;

  FinesRow.fromJson(Map<String, dynamic> j)
      : memberId = _str(j['member']),
        memberNumber = _str(j['member_number']),
        memberName = _str(j['member_name']),
        charged = Money.parse(j['charged']),
        paid = Money.parse(j['paid']),
        outstanding = Money.parse(j['outstanding']),
        count = (j['count'] as num?)?.toInt() ?? 0;
}

class FinesSummary {
  final List<FinesRow> members;
  final Decimal charged;
  final Decimal paid;
  final Decimal outstanding;
  final Decimal waived;
  final bool canCharge;
  final bool canRecordPayment;
  final bool canWaive;

  FinesSummary.fromJson(Map<String, dynamic> j)
      : members = _list(j['members']).map(FinesRow.fromJson).toList(),
        charged = Money.parse((j['totals'] as Map?)?['charged']),
        paid = Money.parse((j['totals'] as Map?)?['paid']),
        outstanding = Money.parse((j['totals'] as Map?)?['outstanding']),
        waived = Money.parse((j['totals'] as Map?)?['waived']),
        canCharge = j['can_charge'] == true,
        canRecordPayment = j['can_record_payment'] == true,
        canWaive = j['can_waive'] == true;
}

/// A fine the meeting register says should be charged, before anyone confirms.
class FineProposal {
  final String memberId;
  final String memberName;
  final String memberNumber;
  final String offenceTypeId;
  final String offence;
  final Decimal amount;
  final bool alreadyCharged;

  FineProposal.fromJson(Map<String, dynamic> j)
      : memberId = _str(j['member']),
        memberName = _str(j['member_name']),
        memberNumber = _str(j['member_number']),
        offenceTypeId = _str(j['offence_type']),
        offence = _str(j['offence']),
        amount = Money.parse(j['amount']),
        alreadyCharged = j['already_charged'] == true;
}
