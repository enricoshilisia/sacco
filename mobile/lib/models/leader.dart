import 'package:decimal/decimal.dart';

import '../core/money.dart';

// Staff/leader data shapes. Mirrors backend reports/, accounting/,
// distributions/ and members/ serializers. Money is Decimal.

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
String _str(Object? v) => v?.toString() ?? '';
List<Map<String, dynamic>> _list(Object? v) => v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

// --- Reports (one generic shape for every report) ----------------------------

class ReportColumn {
  final String key;
  final String label;
  final String kind; // text | money | date | number | percent

  ReportColumn.fromJson(Map<String, dynamic> j)
      : key = _str(j['key']),
        label = _str(j['label']),
        kind = _str(j['kind']);

  bool get isNumeric => kind == 'money' || kind == 'number' || kind == 'percent';
}

class ReportSection {
  final String title;
  final List<ReportColumn> columns;
  final List<List<String>> rows;
  final List<String>? totals;

  ReportSection.fromJson(Map<String, dynamic> j)
      : title = _str(j['title']),
        columns = _list(j['columns']).map(ReportColumn.fromJson).toList(),
        rows = ((j['rows'] as List?) ?? const []).map((r) => (r as List).map(_str).toList()).toList(),
        totals = (j['totals'] as List?)?.map(_str).toList();
}

class ReportFigure {
  final String label;
  final String value;
  final String kind;

  ReportFigure.fromJson(Map<String, dynamic> j)
      : label = _str(j['label']),
        value = _str(j['value']),
        kind = _str(j['kind']);
}

class ReportCheck {
  final String label;
  final bool ok;
  final String detail;

  ReportCheck.fromJson(Map<String, dynamic> j)
      : label = _str(j['label']),
        ok = j['ok'] == true,
        detail = _str(j['detail']);
}

class Report {
  final String key;
  final String title;
  final String period;
  final String generatedBy;
  final DateTime? generatedAt;
  final List<ReportFigure> summary;
  final List<ReportSection> sections;
  final List<ReportCheck> checks;

  Report.fromJson(Map<String, dynamic> j)
      : key = _str(j['key']),
        title = _str(j['title']),
        period = _str(j['period']),
        generatedBy = _str(j['generated_by']),
        generatedAt = _date(j['generated_at']),
        summary = _list(j['summary']).map(ReportFigure.fromJson).toList(),
        sections = _list(j['sections']).map(ReportSection.fromJson).toList(),
        checks = _list(j['checks']).map(ReportCheck.fromJson).toList();
}

class ReportCatalogItem {
  final String key;
  final String params; // as_of | period | account_period

  ReportCatalogItem.fromJson(Map<String, dynamic> j)
      : key = _str(j['key']),
        params = _str(j['params']);
}

class ReportCatalog {
  final bool canExport;
  final List<ReportCatalogItem> reports;

  ReportCatalog.fromJson(Map<String, dynamic> j)
      : canExport = j['can_export'] == true,
        reports = _list(j['reports']).map(ReportCatalogItem.fromJson).toList();
}

/// GET /api/reports/summary/
class FinanceSummary {
  final Decimal cash;
  final Decimal savings;
  final Decimal shareCapital;
  final Decimal loansOutstanding;
  final Decimal welfareFund;
  final Decimal incomeYtd;
  final Decimal expensesYtd;
  final Decimal surplusYtd;
  final String par30;
  final Decimal collectionsToday;
  final int activeMembers;
  final bool ledgerBalanced;

  FinanceSummary.fromJson(Map<String, dynamic> j)
      : cash = Money.parse(j['cash']),
        savings = Money.parse(j['savings']),
        shareCapital = Money.parse(j['share_capital']),
        loansOutstanding = Money.parse(j['loans_outstanding']),
        welfareFund = Money.parse(j['welfare_fund']),
        incomeYtd = Money.parse(j['income_ytd']),
        expensesYtd = Money.parse(j['expenses_ytd']),
        surplusYtd = Money.parse(j['surplus_ytd']),
        par30 = _str(j['par30']),
        collectionsToday = Money.parse(j['collections_today']),
        activeMembers = (j['active_members'] as num?)?.toInt() ?? 0,
        ledgerBalanced = j['ledger_balanced'] == true;
}

class LeaderTask {
  final String key;
  final int count;

  LeaderTask.fromJson(Map<String, dynamic> j)
      : key = _str(j['key']),
        count = (j['count'] as num?)?.toInt() ?? 0;
}

// --- Ledger ------------------------------------------------------------------

class LedgerAccount {
  final String id;
  final String code;
  final String name;
  final String accountType;
  final bool isControl;
  final bool isActive;

  LedgerAccount.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        code = _str(j['code']),
        name = _str(j['name']),
        accountType = _str(j['account_type']),
        isControl = j['is_control_account'] == true,
        isActive = j['is_active'] != false;

  String get label => '$code · $name';
}

class JournalLineItem {
  final String accountCode;
  final String accountName;
  final Decimal debit;
  final Decimal credit;
  final String memberName;
  final String description;

  JournalLineItem.fromJson(Map<String, dynamic> j)
      : accountCode = _str(j['account_code']),
        accountName = _str(j['account_name']),
        debit = Money.parse(j['debit']),
        credit = Money.parse(j['credit']),
        memberName = _str(j['member_name']),
        description = _str(j['description']);
}

class JournalEntryItem {
  final String id;
  final String reference;
  final String description;
  final DateTime? entryDate;
  final String reversesReference;
  final String reversedByReference;
  final String createdBy;
  final List<JournalLineItem> lines;

  JournalEntryItem.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        reference = _str(j['reference']),
        description = _str(j['description']),
        entryDate = _date(j['entry_date']),
        reversesReference = _str(j['reverses_reference']),
        reversedByReference = _str(j['reversed_by_reference']),
        createdBy = _str(j['created_by_name']),
        lines = _list(j['lines']).map(JournalLineItem.fromJson).toList();

  Decimal get total => Money.sum(lines.map((l) => l.debit));
  bool get canBeReversed => reversedByReference.isEmpty && reversesReference.isEmpty;
}

// --- Dividends / interest runs -----------------------------------------------

class DistributionRunItem {
  final String id;
  final String kind; // DIVIDEND | INTEREST
  final String productName;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final Decimal rate;
  final String status; // PENDING_APPROVAL | APPROVED | REJECTED
  final String description;
  final int memberCount;
  final String proposedBy;
  final Decimal totalGross;
  final Decimal totalWht;
  final Decimal totalNet;
  final bool whtConfirmed;
  final String rejectionReason;

  DistributionRunItem.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        kind = _str(j['kind']),
        productName = _str(j['product_name']),
        periodStart = _date(j['period_start']),
        periodEnd = _date(j['period_end']),
        rate = Money.parse(j['rate']),
        status = _str(j['status']),
        description = _str(j['description']),
        memberCount = (j['member_count'] as num?)?.toInt() ?? 0,
        proposedBy = _str(j['proposed_by_name']),
        totalGross = Money.parse(j['total_gross']),
        totalWht = Money.parse(j['total_wht']),
        totalNet = Money.parse(j['total_net']),
        whtConfirmed = j['wht_rates_confirmed_by_tax_adviser'] == true,
        rejectionReason = _str(j['rejection_reason']);

  bool get isPending => status == 'PENDING_APPROVAL';
}

// --- Members (staff view) ----------------------------------------------------

class MemberListItem {
  final String id;
  final String memberNumber;
  final String fullName;
  final String status;
  final String phoneNumber;
  final bool isKycVerified;
  final String profileStatus;
  final String photo;

  MemberListItem.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        memberNumber = _str(j['member_number']),
        fullName = _str(j['full_name']),
        status = _str(j['status']),
        phoneNumber = _str(j['phone_number']),
        isKycVerified = j['is_kyc_verified'] == true,
        profileStatus = _str(j['profile_status']),
        photo = _str(j['photo']);
}
