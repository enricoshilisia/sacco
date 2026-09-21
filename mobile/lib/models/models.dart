import 'package:decimal/decimal.dart';

import '../core/money.dart';

// Shapes mirror the DRF serializers in backend/<app>/serializers.py.
// Every money field is parsed with Money.parse into Decimal.

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
String _str(Object? value) => value?.toString() ?? '';

List<Map<String, dynamic>> _list(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

/// DRF PageNumberPagination wraps list endpoints in {"results": [...]}.
List<Map<String, dynamic>> results(Object? body) => body is Map ? _list(body['results']) : _list(body);

/// GET /api/tenant/me/ - the logged-in user's roles/permissions in this SACCO.
class TenantProfile {
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final List<String> roles;
  final Set<String> permissions;
  final bool mustChangePassword;
  final String userId;

  TenantProfile.fromJson(Map<String, dynamic> json)
      : userId = _str((json['user'] as Map?)?['id']),
        mustChangePassword = (json['user'] as Map?)?['must_change_password'] == true,
        firstName = _str((json['user'] as Map?)?['first_name']),
        lastName = _str((json['user'] as Map?)?['last_name']),
        phoneNumber = _str((json['user'] as Map?)?['phone_number']),
        roles = _list(json['memberships']).map((m) => _str(m['role_name'])).toList(),
        permissions = ((json['permissions'] as List?) ?? const []).map((p) => p.toString()).toSet();

  bool can(String code) => permissions.contains(code);

  bool canAny(Iterable<String> codes) => codes.any(permissions.contains);

  // Leader modules, each unlocked by the permissions its screens need.
  bool get hasWelfareTools => permissions.any((p) => p.startsWith('welfare.'));
  bool get hasFinance => canAny(const ['accounting.view_trial_balance', 'accounting.view_ledger']);
  bool get hasReports => canAny(const [
        'accounting.view_trial_balance', 'accounting.view_ledger', 'loans.view',
        'payments.view_transactions', 'distributions.view',
      ]);
  bool get hasLoanDesk => canAny(const ['loans.appraise', 'loans.approve', 'loans.reject', 'loans.disburse', 'loans.repay']);
  bool get hasMembers => can('members.view');
  bool get hasDistributions => can('distributions.view');
  bool get hasApprovals => canAny(const ['members.approve_changes', 'members.approve_admission']);
  bool get hasAdmin => canAny(const ['users.view', 'audit.view', 'accesscontrol.assign_roles']);
  bool get hasMeetings => canAny(const ['governance.call_meeting', 'governance.take_attendance']);
  bool get hasActivity => can('members.approve_changes');

  /// Any leader module this app offers.
  bool get hasStaffTools =>
      hasWelfareTools || hasFinance || hasReports || hasLoanDesk || hasMembers || hasDistributions || hasApprovals ||
      hasMeetings || hasAdmin;
}

/// GET /api/members/me/
class Member {
  final String id;
  final String memberNumber;
  final String category;
  final String status;
  final String firstName;
  final String lastName;
  final String otherNames;
  final String idType;
  final String idNumber;
  final String phoneNumber;
  final String email;
  final String physicalAddress;
  final String? photo;
  final bool isKycVerified;
  final DateTime? dateJoined;
  final DateTime? dateOfBirth;
  final String gender;
  final String maritalStatus;
  final String occupation;
  final String employer;
  final String county;
  final String profileStatus; // DRAFT / PENDING / APPROVED

  Member.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        memberNumber = _str(json['member_number']),
        category = _str(json['category']),
        status = _str(json['status']),
        firstName = _str(json['first_name']),
        lastName = _str(json['last_name']),
        otherNames = _str(json['other_names']),
        idType = _str(json['id_type']),
        idNumber = _str(json['id_number']),
        phoneNumber = _str(json['phone_number']),
        email = _str(json['email']),
        physicalAddress = _str(json['physical_address']),
        photo = json['photo'] as String?,
        isKycVerified = json['is_kyc_verified'] == true,
        dateJoined = _date(json['date_joined']),
        dateOfBirth = _date(json['date_of_birth']),
        gender = _str(json['gender']),
        maritalStatus = _str(json['marital_status']),
        occupation = _str(json['occupation']),
        employer = _str(json['employer']),
        county = _str(json['county']),
        profileStatus = _str(json['profile_status']).isEmpty ? 'DRAFT' : _str(json['profile_status']);

  bool get profileApproved => profileStatus == 'APPROVED';

  String get fullName => [firstName, otherNames, lastName].where((s) => s.isNotEmpty).join(' ');
}

class LedgerLine {
  final String id;
  final String type; // DEPOSIT / WITHDRAWAL for savings; CONTRIBUTION for shares
  final Decimal amount;
  final DateTime? date;

  LedgerLine({required this.id, required this.type, required this.amount, required this.date});
}

class SavingsAccount {
  final String id;
  final String productId;
  final String productName;
  final String productType;
  final String accountNumber;
  final Decimal balance;
  final List<LedgerLine> transactions;

  SavingsAccount.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        productId = _str(json['product']),
        productName = _str(json['product_name']),
        productType = _str(json['product_type']),
        accountNumber = _str(json['account_number']),
        balance = Money.parse(json['balance']),
        transactions = _list(json['transactions'])
            .map((t) => LedgerLine(
                  id: _str(t['id']),
                  type: _str(t['transaction_type']),
                  amount: Money.parse(t['amount']),
                  date: _date(t['transaction_date']),
                ))
            .toList();
}

/// GET /api/savings/me/statement/ - share capital and deposits are kept
/// separate on purpose (CLAUDE.md rule 5): different accounts, different rules.
class Statement {
  final Decimal sharesBalance;
  final List<LedgerLine> shareContributions;
  final List<SavingsAccount> savingsAccounts;

  /// Total deposits from the ledger. Use this, never a sum of
  /// savingsAccounts[].balance - see backend savings.views.build_member_statement.
  final Decimal savingsTotal;

  /// Portion of savingsTotal locked as pledges on loans this member guarantees.
  final Decimal savingsPledged;

  Statement.fromJson(Map<String, dynamic> json)
      : savingsTotal = Money.parse(json['savings_total']),
        savingsPledged = Money.parse(json['savings_pledged']),
        sharesBalance = Money.parse((json['shares'] as Map?)?['balance']),
        shareContributions = _list((json['shares'] as Map?)?['contributions'])
            .map((c) => LedgerLine(
                  id: _str(c['id']),
                  type: 'CONTRIBUTION',
                  amount: Money.parse(c['amount']),
                  date: _date(c['transaction_date']),
                ))
            .toList(),
        savingsAccounts = _list(json['savings_accounts']).map(SavingsAccount.fromJson).toList();
}

class SavingsProduct {
  final String id;
  final String name;
  final String productType;
  final bool isActive;

  SavingsProduct.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        name = _str(json['name']),
        productType = _str(json['product_type']),
        isActive = json['is_active'] != false;
}

class LoanProduct {
  final String id;
  final String name;
  final String interestMethod;
  final Decimal interestRate;
  final int minTermMonths;
  final int maxTermMonths;
  /// Null = the SACCO's default multiplier applies (TenantConfig).
  final Decimal? maxMultipleOfDeposits;
  final bool requiresGuarantors;
  final int minGuarantors;
  final bool isActive;

  LoanProduct.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        name = _str(json['name']),
        interestMethod = _str(json['interest_method']),
        interestRate = Money.parse(json['interest_rate']),
        minTermMonths = (json['min_term_months'] as num?)?.toInt() ?? 1,
        maxTermMonths = (json['max_term_months'] as num?)?.toInt() ?? 1,
        maxMultipleOfDeposits =
            json['max_multiple_of_deposits'] == null ? null : Money.parse(json['max_multiple_of_deposits']),
        requiresGuarantors = json['requires_guarantors'] == true,
        minGuarantors = (json['min_guarantors'] as num?)?.toInt() ?? 0,
        isActive = json['is_active'] != false;
}

class LoanGuarantor {
  final String id;
  final String loanId;
  final String guarantorName;
  final String guarantorMemberNumber;
  final String borrowerName;
  final Decimal pledgedAmount;
  final String status; // PENDING / CONSENTED / DECLINED / RELEASED
  final DateTime? requestedAt;

  LoanGuarantor.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        loanId = _str(json['loan']),
        guarantorName = _str(json['guarantor_name']),
        guarantorMemberNumber = _str(json['guarantor_member_number']),
        borrowerName = _str(json['borrower_name']),
        pledgedAmount = Money.parse(json['pledged_amount']),
        status = _str(json['status']),
        requestedAt = _date(json['requested_at']);
}

class ScheduleRow {
  final int installmentNumber;
  final DateTime? dueDate;
  final Decimal totalDue;
  final Decimal paid;
  final bool isPaid;

  ScheduleRow.fromJson(Map<String, dynamic> json)
      : installmentNumber = (json['installment_number'] as num?)?.toInt() ?? 0,
        dueDate = _date(json['due_date']),
        totalDue = Money.parse(json['total_due']),
        paid = Money.parse(json['principal_paid']) + Money.parse(json['interest_paid']),
        isPaid = json['is_paid'] == true;
}

class Repayment {
  final Decimal amount;
  final DateTime? date;
  final String description;

  Repayment.fromJson(Map<String, dynamic> json)
      : amount = Money.parse(json['amount']),
        date = _date(json['transaction_date']),
        description = _str(json['description']);
}

class Loan {
  final String id;
  final String memberId;
  final String memberName;
  final String memberNumber;
  final String appraisalNotes;
  final String appraisedBy;
  final String decidedBy;
  final String disbursementMethod;
  final String productId;
  final String productName;
  final Decimal amountRequested;
  final int termMonths;
  final String purpose;
  final String interestMethod;
  final Decimal interestRate;
  final String status;
  final DateTime? appliedAt;
  final String decisionNotes;
  final bool isAutoDecision;
  final List<LoanGuarantor> guarantors;
  final List<ScheduleRow> schedule;
  final List<Repayment> repayments;
  final Decimal outstandingBalance;
  final bool isOverdue;
  final int daysOverdue;
  final Decimal amountOverdue;

  Loan.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        memberId = _str(json['member']),
        memberName = _str(json['member_name']),
        memberNumber = _str(json['member_number']),
        appraisalNotes = _str(json['appraisal_notes']),
        appraisedBy = _str(json['appraised_by_name']),
        decidedBy = _str(json['decided_by_name']),
        disbursementMethod = _str(json['disbursement_method']),
        productId = _str(json['product']),
        productName = _str(json['product_name']),
        amountRequested = Money.parse(json['amount_requested']),
        termMonths = (json['term_months'] as num?)?.toInt() ?? 0,
        purpose = _str(json['purpose']),
        interestMethod = _str(json['interest_method']),
        interestRate = Money.parse(json['interest_rate']),
        status = _str(json['status']),
        appliedAt = _date(json['applied_at']),
        decisionNotes = _str(json['decision_notes']),
        isAutoDecision = json['is_auto_decision'] == true,
        guarantors = _list(json['guarantors']).map(LoanGuarantor.fromJson).toList(),
        schedule = _list(json['schedule']).map(ScheduleRow.fromJson).toList(),
        repayments = _list(json['repayments']).map(Repayment.fromJson).toList(),
        outstandingBalance = Money.parse(json['outstanding_balance']),
        isOverdue = (json['arrears'] as Map?)?['is_overdue'] == true,
        daysOverdue = ((json['arrears'] as Map?)?['days_overdue'] as num?)?.toInt() ?? 0,
        amountOverdue = Money.parse((json['arrears'] as Map?)?['amount_overdue']);

  bool get isActive => status == 'ACTIVE';
  bool get awaitingGuarantors => status == 'PENDING_GUARANTORS';

  ScheduleRow? get nextInstallment {
    for (final row in schedule) {
      if (!row.isPaid) return row;
    }
    return null;
  }
}

/// A mobile-money collection (backend: payments.PaymentCollection).
class Collection {
  final String id;
  final String purpose;
  final String? productName;
  final Decimal amount;
  final String phoneNumber;
  final String status; // PENDING / SUCCESS / FAILED / CANCELLED
  final String providerReceipt;
  final String failureReason;
  final DateTime? createdAt;

  Collection.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        purpose = _str(json['purpose']),
        productName = json['product_name'] as String?,
        amount = Money.parse(json['amount']),
        phoneNumber = _str(json['phone_number']),
        status = _str(json['status']),
        providerReceipt = _str(json['provider_receipt']),
        failureReason = _str(json['failure_reason']),
        createdAt = _date(json['created_at']);

  bool get isPending => status == 'PENDING';
}

/// GET /api/distributions/me/ - one dividend or interest line.
class DistributionEntry {
  final String id;
  final bool isInterest; // INTEREST on deposits vs DIVIDEND on share capital
  final DateTime? periodEnd;
  final String description;
  final Decimal basisBalance;
  final Decimal gross;
  final Decimal wht;
  final Decimal net;
  final String status; // PROPOSED / POSTED / PAID

  DistributionEntry.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        isInterest = json['run_kind'] == 'INTEREST',
        periodEnd = _date(json['run_period_end']),
        description = _str(json['run_description']),
        basisBalance = Money.parse(json['basis_balance']),
        gross = Money.parse(json['gross_amount']),
        wht = Money.parse(json['wht_amount']),
        net = Money.parse(json['net_amount']),
        status = _str(json['status']);
}
