import 'package:decimal/decimal.dart';

import '../core/money.dart';

// Mirrors backend/welfare/serializers.py. Money fields are Decimal.

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
String _str(Object? v) => v?.toString() ?? '';
List<Map<String, dynamic>> _list(Object? v) => v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

class MemberBrief {
  final String id;
  final String memberNumber;
  final String fullName;
  final String phoneNumber;

  MemberBrief.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        memberNumber = _str(j['member_number']),
        fullName = _str(j['full_name']),
        phoneNumber = _str(j['phone_number']);
}

class WelfareSummary {
  final Decimal balance; // unused yearly contributions
  final Decimal owed; // outstanding dues for past cases
  final Decimal yearlyContribution;
  final Decimal paidThisYear;
  final int year;

  WelfareSummary.fromJson(Map<String, dynamic> j)
      : balance = Money.parse(j['balance']),
        owed = Money.parse(j['owed']),
        yearlyContribution = Money.parse(j['yearly_contribution']),
        paidThisYear = Money.parse(j['paid_this_year']),
        year = (j['year'] as num?)?.toInt() ?? DateTime.now().year;

  /// What's left of this year's expected contribution.
  Decimal get yearlyRemaining {
    final left = yearlyContribution - paidThisYear;
    return left > Decimal.zero ? left : Decimal.zero;
  }
}

class WelfareContribution {
  final String id;
  final String caseId;
  final String caseTypeName;
  final String beneficiaryName;
  final String affectedPerson;
  final String memberNumber;
  final String memberName;
  final Decimal amount;
  final Decimal fromBalance;
  final Decimal owed;
  final Decimal outstanding;
  final DateTime? createdAt;

  WelfareContribution.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        caseId = _str(j['case']),
        caseTypeName = _str(j['case_type_name']),
        beneficiaryName = _str(j['beneficiary_name']),
        affectedPerson = _str(j['affected_person']),
        memberNumber = _str(j['member_number']),
        memberName = _str(j['member_name']),
        amount = Money.parse(j['amount']),
        fromBalance = Money.parse(j['from_balance']),
        owed = Money.parse(j['owed']),
        outstanding = Money.parse(j['outstanding']),
        createdAt = _date(j['created_at']);
}

class WelfarePaymentRecord {
  final Decimal amount;
  final Decimal appliedToDues;
  final Decimal toBalance;
  final String method;
  final String reference;
  final DateTime? date;

  WelfarePaymentRecord.fromJson(Map<String, dynamic> j)
      : amount = Money.parse(j['amount']),
        appliedToDues = Money.parse(j['applied_to_dues']),
        toBalance = Money.parse(j['to_balance']),
        method = _str(j['method']),
        reference = _str(j['reference']),
        date = _date(j['transaction_date']);
}

/// GET `/api/welfare/me/` and `/api/welfare/members/{id}/`
class MemberWelfare {
  final MemberBrief member;
  final WelfareSummary summary;
  final List<WelfareContribution> contributions;
  final List<WelfarePaymentRecord> payments;

  MemberWelfare.fromJson(Map<String, dynamic> j)
      : member = MemberBrief.fromJson((j['member'] as Map<String, dynamic>?) ?? const {}),
        summary = WelfareSummary.fromJson((j['summary'] as Map<String, dynamic>?) ?? const {}),
        contributions = _list(j['contributions']).map(WelfareContribution.fromJson).toList(),
        payments = _list(j['payments']).map(WelfarePaymentRecord.fromJson).toList();
}

class WelfareCaseType {
  final String id;
  final String name;
  final String description;
  final Decimal contributionPerMember;
  final bool beneficiaryContributes;
  final List<String> covers; // SELF and/or family relationships
  final int? childMaxAge;
  final bool isActive;

  WelfareCaseType.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        name = _str(j['name']),
        description = _str(j['description']),
        contributionPerMember = Money.parse(j['contribution_per_member']),
        beneficiaryContributes = j['beneficiary_contributes'] == true,
        covers = ((j['covers'] as List?) ?? const ['SELF']).map((e) => e.toString()).toList(),
        childMaxAge = (j['child_max_age'] as num?)?.toInt(),
        isActive = j['is_active'] != false;
}

class WelfarePayout {
  final Decimal amount;
  final String method;
  final String reference;
  final String paidTo;
  final DateTime? paidOn;
  final String recordedBy;

  WelfarePayout.fromJson(Map<String, dynamic> j)
      : amount = Money.parse(j['amount']),
        method = _str(j['method']),
        reference = _str(j['reference']),
        paidTo = _str(j['paid_to']),
        paidOn = _date(j['paid_on']),
        recordedBy = _str(j['recorded_by_name']);
}

class WelfareCase {
  final String id;
  final String caseTypeName;
  final MemberBrief beneficiary;
  final String affectedPerson;
  final String description;
  final Decimal contributionPerMember;
  final String status; // PENDING_APPROVAL / APPROVED / REJECTED / CLOSED
  final String createdBy;
  final DateTime? createdAt;
  final String decidedBy;
  final String decisionNotes;
  final DateTime? leviedAt;
  final int membersLevied;
  final Decimal totalLevied;
  final Decimal collected;
  final Decimal outstanding;
  final Decimal paidOut;
  final Decimal availableToPay;
  final List<WelfarePayout> payouts;

  WelfareCase.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        caseTypeName = _str(j['case_type_name']),
        beneficiary = MemberBrief.fromJson((j['beneficiary'] as Map<String, dynamic>?) ?? const {}),
        affectedPerson = _str(j['affected_person']),
        description = _str(j['description']),
        contributionPerMember = Money.parse(j['contribution_per_member']),
        status = _str(j['status']),
        createdBy = _str(j['created_by_name']),
        createdAt = _date(j['created_at']),
        decidedBy = _str(j['decided_by_name']),
        decisionNotes = _str(j['decision_notes']),
        leviedAt = _date(j['levied_at']),
        membersLevied = (j['members_levied'] as num?)?.toInt() ?? 0,
        totalLevied = Money.parse(j['total_levied']),
        collected = Money.parse(j['collected']),
        outstanding = Money.parse(j['outstanding']),
        paidOut = Money.parse(j['paid_out']),
        availableToPay = Money.parse(j['available_to_pay']),
        payouts = _list(j['payouts']).map(WelfarePayout.fromJson).toList();

  bool get isPending => status == 'PENDING_APPROVAL';
  bool get isOpen => status == 'APPROVED';
}
