import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../models/leader.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'sacco_api.dart';

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Report parameters: an "as at" date, or a period (optionally for one account).
class ReportParams {
  final DateTime? asOf;
  final DateTime? start;
  final DateTime? end;
  final String? accountCode;
  const ReportParams({this.asOf, this.start, this.end, this.accountCode});

  Map<String, dynamic> toQuery() => {
        if (asOf != null) 'as_of': isoDate(asOf!),
        if (start != null) 'start': isoDate(start!),
        if (end != null) 'end': isoDate(end!),
        'account': ?accountCode,
      };
}

/// Staff/leader endpoints. Every action is still permission-checked by the
/// backend; the app only hides what a role can't use.
extension LeaderApi on SaccoApi {
  // --- Dashboard & tasks -------------------------------------------------------

  Future<FinanceSummary> financeSummary() async =>
      FinanceSummary.fromJson(await client.get<Map<String, dynamic>>('/api/reports/summary/'));

  Future<List<LeaderTask>> myTasks() async =>
      (((await client.get<Map<String, dynamic>>('/api/reports/my-tasks/'))['tasks'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LeaderTask.fromJson)
          .toList();

  // --- Reports -----------------------------------------------------------------

  Future<ReportCatalog> reportCatalog() async =>
      ReportCatalog.fromJson(await client.get<Map<String, dynamic>>('/api/reports/'));

  Future<Report> report(String key, ReportParams params) async =>
      Report.fromJson(await client.get<Map<String, dynamic>>('/api/reports/$key/', query: params.toQuery()));

  /// The official CSV (with audit header) for handing to auditors.
  Future<Uint8List> reportCsv(String key, ReportParams params) async {
    try {
      final response = await client.dio.get<List<int>>(
        '/api/reports/$key/',
        queryParameters: {...params.toQuery(), 'export': 'csv'},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    } catch (e) {
      throw toApiException(e);
    }
  }

  // --- Ledger ------------------------------------------------------------------

  Future<List<LedgerAccount>> accounts() async =>
      ((await client.get<Object?>('/api/accounting/accounts/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LedgerAccount.fromJson)
          .toList();

  Future<void> createAccount({required String code, required String name, required String type}) =>
      client.post<Object?>('/api/accounting/accounts/', data: {'code': code, 'name': name, 'account_type': type});

  Future<({List<JournalEntryItem> items, bool hasMore})> journal({int page = 1}) async {
    final body = await client.get<Map<String, dynamic>>('/api/accounting/journal-entries/', query: {'page': '$page'});
    return (items: results(body).map(JournalEntryItem.fromJson).toList(), hasMore: body['next'] != null);
  }

  Future<JournalEntryItem> postJournal({
    required String description,
    required DateTime date,
    required List<({String accountId, Decimal debit, Decimal credit, String memo})> lines,
  }) async =>
      JournalEntryItem.fromJson(await client.post<Map<String, dynamic>>('/api/accounting/journal-entries/', data: {
        'description': description,
        'entry_date': isoDate(date),
        'lines': [
          for (final l in lines)
            {
              'account': l.accountId,
              'debit': l.debit.toStringAsFixed(2),
              'credit': l.credit.toStringAsFixed(2),
              'description': l.memo,
            },
        ],
      }));

  Future<void> reverseJournal(String id, String reason) =>
      client.post<Object?>('/api/accounting/journal-entries/$id/reverse/', data: {'reason': reason});

  // --- Dividend / interest runs ------------------------------------------------

  Future<List<DistributionRunItem>> distributionRuns() async =>
      results(await client.get<Object?>('/api/distributions/runs/')).map(DistributionRunItem.fromJson).toList();

  Future<DistributionRunItem> distributionRun(String id) async =>
      DistributionRunItem.fromJson(await client.get<Map<String, dynamic>>('/api/distributions/runs/$id/'));

  Future<void> approveDistributionRun(String id) => client.post<Object?>('/api/distributions/runs/$id/approve/');

  Future<void> rejectDistributionRun(String id, String reason) =>
      client.post<Object?>('/api/distributions/runs/$id/reject/', data: {'reason': reason});

  Future<void> payoutDistributionRun(String id) => client.post<Object?>('/api/distributions/runs/$id/payout-all/');

  Future<void> proposeDividendRun({
    required DateTime start,
    required DateTime end,
    required Decimal rate,
    required String description,
  }) =>
      client.post<Object?>('/api/distributions/runs/dividend/', data: {
        'period_start': isoDate(start),
        'period_end': isoDate(end),
        'rate': rate.toString(),
        'description': description,
      });

  Future<void> proposeInterestRun({
    required String productId,
    required DateTime start,
    required DateTime end,
    Decimal? rate,
    required String description,
  }) =>
      client.post<Object?>('/api/distributions/runs/interest/', data: {
        'savings_product': productId,
        'period_start': isoDate(start),
        'period_end': isoDate(end),
        'rate': rate?.toString(),
        'description': description,
      });

  // --- Loan desk ---------------------------------------------------------------

  Future<List<Loan>> loansByStatus(List<String> statuses) async =>
      results(await client.get<Object?>('/api/loans/', query: {'status': statuses.join(',')})).map(Loan.fromJson).toList();

  Future<List<Loan>> memberLoans(String memberId) async =>
      results(await client.get<Object?>('/api/loans/', query: {'member': memberId})).map(Loan.fromJson).toList();

  Future<void> appraiseLoan(String id, String notes) =>
      client.post<Object?>('/api/loans/$id/appraise/', data: {'notes': notes});

  Future<void> decideLoan(String id, {required bool approve, required String notes}) =>
      client.post<Object?>('/api/loans/$id/decide/', data: {'approved': approve, 'notes': notes});

  Future<void> disburseLoanToSavings(String id, String savingsProductId) =>
      client.post<Object?>('/api/loans/$id/disburse/savings/', data: {'product': savingsProductId});

  Future<void> disburseLoanMobileMoney(String id, {required String phone, required String idempotencyKey}) =>
      client.post<Object?>('/api/loans/$id/disburse/mobile-money/', data: {'phone_number': phone, 'idempotency_key': idempotencyKey});

  Future<void> recordLoanRepayment(String id, {required Decimal amount, required DateTime date, required String note}) =>
      client.post<Object?>('/api/loans/$id/repay/', data: {
        'amount': amount.toStringAsFixed(2),
        'transaction_date': isoDate(date),
        'description': note,
      });

  // --- Members & counter ------------------------------------------------------

  Future<List<MemberListItem>> searchMembers(String query) async =>
      results(await client.get<Object?>('/api/members/', query: {'search': query}))
          .map(MemberListItem.fromJson)
          .toList();

  Future<Member> member(String id) async => Member.fromJson(await client.get<Map<String, dynamic>>('/api/members/$id/'));

  Future<Statement> memberStatement(String id) async =>
      Statement.fromJson(await client.get<Map<String, dynamic>>('/api/savings/members/$id/statement/'));

  Future<void> verifyKyc(String memberId) => client.post<Object?>('/api/members/$memberId/verify-kyc/');

  Future<void> counterContributeShares(String memberId, {required Decimal amount, required DateTime date, required String note}) =>
      client.post<Object?>('/api/savings/members/$memberId/shares/contribute/', data: {
        'amount': amount.toStringAsFixed(2),
        'transaction_date': isoDate(date),
        'description': note,
      });

  Future<void> counterDeposit(String memberId,
          {required String productId, required Decimal amount, required DateTime date, required String note}) =>
      client.post<Object?>('/api/savings/members/$memberId/deposit/', data: {
        'product': productId,
        'amount': amount.toStringAsFixed(2),
        'transaction_date': isoDate(date),
        'description': note,
      });

  Future<void> counterWithdraw(String memberId,
          {required String savingsAccountId, required Decimal amount, required DateTime date, required String note}) =>
      client.post<Object?>('/api/savings/members/$memberId/withdraw/', data: {
        'savings_account': savingsAccountId,
        'amount': amount.toStringAsFixed(2),
        'transaction_date': isoDate(date),
        'description': note,
      });
}
