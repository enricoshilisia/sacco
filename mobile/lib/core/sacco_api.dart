import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../config.dart';
import '../models/models.dart';
import '../models/sacco.dart';
import '../models/welfare.dart';
import 'api_client.dart';
import 'money.dart';

/// Public-schema call: resolve a SACCO code before any tenant is known.
Future<Sacco> lookupSacco(String code) async {
  final dio = Dio(BaseOptions(baseUrl: AppConfig.publicApiBaseUrl, connectTimeout: const Duration(seconds: 15)));
  final label = code.trim().toLowerCase().split('.').first;
  try {
    final response = await dio.get('/api/public/saccos/${Uri.encodeComponent(label)}/');
    return Sacco.fromJson(response.data as Map<String, dynamic>);
  } catch (error) {
    throw toApiException(error);
  }
}

/// Every member-facing endpoint the app uses. All are the backend's
/// self-service ("me") endpoints, where ownership - the member linked to
/// the logged-in user - is the access check.
class SaccoApi {
  final ApiClient client;
  SaccoApi(this.client);

  Future<({String access, String refresh})> login(String phone, String password) async {
    final data = await client.post<Map<String, dynamic>>(
      '/api/auth/token/',
      data: {'phone_number': phone, 'password': password},
      auth: false,
    );
    return (access: data['access'] as String, refresh: data['refresh'] as String);
  }

  Future<TenantProfile> tenantProfile() async =>
      TenantProfile.fromJson(await client.get<Map<String, dynamic>>('/api/tenant/me/'));

  Future<Member> myMember() async => Member.fromJson(await client.get<Map<String, dynamic>>('/api/members/me/'));

  Future<Member> updateMyContact({required String phone, required String email, required String address}) async =>
      Member.fromJson(await client.patch<Map<String, dynamic>>(
        '/api/members/me/',
        data: {'phone_number': phone, 'email': email, 'physical_address': address},
      ));

  /// Uploads a profile photo (already shrunk on the phone; the server also
  /// accepts any format and resizes, so HEIC or huge files still work).
  Future<Member> uploadMyPhoto(String filePath) async {
    final form = FormData.fromMap({'photo': await MultipartFile.fromFile(filePath, filename: 'photo.jpg')});
    return Member.fromJson(await client.post<Map<String, dynamic>>('/api/members/me/photo/', data: form));
  }

  Future<Statement> myStatement() async =>
      Statement.fromJson(await client.get<Map<String, dynamic>>('/api/savings/me/statement/'));

  Future<List<SavingsProduct>> savingsProducts() async => results(await client.get<Object?>('/api/savings/products/'))
      .map(SavingsProduct.fromJson)
      .where((p) => p.isActive)
      .toList();

  Future<List<LoanProduct>> loanProducts() async => results(await client.get<Object?>('/api/loans/products/'))
      .map(LoanProduct.fromJson)
      .where((p) => p.isActive)
      .toList();

  Future<List<Loan>> myLoans() async => results(await client.get<Object?>('/api/loans/me/')).map(Loan.fromJson).toList();

  Future<Loan> loan(String id) async => Loan.fromJson(await client.get<Map<String, dynamic>>('/api/loans/$id/'));

  Future<Loan> applyForLoan({
    required String productId,
    required Decimal amount,
    required int termMonths,
    required String purpose,
  }) async =>
      Loan.fromJson(await client.post<Map<String, dynamic>>('/api/loans/me/apply/', data: {
        'product': productId,
        'amount_requested': amount.toStringAsFixed(2),
        'term_months': termMonths,
        'purpose': purpose,
      }));

  Future<void> addGuarantor({required String loanId, required String memberNumber, required Decimal pledged}) =>
      client.post<Object?>('/api/loans/$loanId/guarantors/', data: {
        'guarantor_member_number': memberNumber,
        'pledged_amount': pledged.toStringAsFixed(2),
      });

  Future<void> submitForAppraisal(String loanId) => client.post<Object?>('/api/loans/$loanId/submit/');

  Future<List<LoanGuarantor>> myGuaranteeRequests() async =>
      results(await client.get<Object?>('/api/loans/me/guarantee-requests/')).map(LoanGuarantor.fromJson).toList();

  Future<void> respondToGuarantee(String guarantorId, {required bool accept}) =>
      client.post<Object?>('/api/loans/guarantors/$guarantorId/respond/', data: {'accept': accept});

  Future<List<DistributionEntry>> myDistributions() async =>
      results(await client.get<Object?>('/api/distributions/me/')).map(DistributionEntry.fromJson).toList();

  /// Starts an STK push / checkout on the member's phone. Nothing is
  /// posted to the ledger here - only the provider's confirmed callback
  /// does that. [idempotencyKey] must be reused on a retry of the same
  /// payment so a timed-out-then-retried request can't charge twice
  /// (CLAUDE.md rule 4).
  Future<Collection> collect({
    required String purpose, // SAVINGS_DEPOSIT, SHARE_CONTRIBUTION or WELFARE_CONTRIBUTION
    String? productId,
    required Decimal amount,
    required String phone,
    required String idempotencyKey,
  }) async =>
      Collection.fromJson(await client.post<Map<String, dynamic>>('/api/payments/me/collect/', data: {
        'purpose': purpose,
        'product': ?productId,
        'amount': amount.toStringAsFixed(2),
        'phone_number': phone,
        'idempotency_key': idempotencyKey,
      }));

  Future<Collection> myCollection(String id) async =>
      Collection.fromJson(await client.get<Map<String, dynamic>>('/api/payments/me/collections/$id/'));

  Future<List<Collection>> myCollections() async =>
      results(await client.get<Object?>('/api/payments/me/collections/')).map(Collection.fromJson).toList();

  // --- Welfare ------------------------------------------------------------

  Future<MemberWelfare> myWelfare() async =>
      MemberWelfare.fromJson(await client.get<Map<String, dynamic>>('/api/welfare/me/'));

  Future<List<WelfareCaseType>> welfareCaseTypes({bool activeOnly = false}) async =>
      ((await client.get<Object?>('/api/welfare/case-types/', query: activeOnly ? {'active': 'true'} : null))
              as List? ??
          const [])
          .whereType<Map<String, dynamic>>()
          .map(WelfareCaseType.fromJson)
          .toList();

  Future<void> saveWelfareCaseType({
    String? id,
    required String name,
    required String description,
    required Decimal contributionPerMember,
    required bool beneficiaryContributes,
    required bool isActive,
  }) {
    final data = {
      'name': name,
      'description': description,
      'contribution_per_member': contributionPerMember.toStringAsFixed(2),
      'beneficiary_contributes': beneficiaryContributes,
      'is_active': isActive,
    };
    return id == null
        ? client.post<Object?>('/api/welfare/case-types/', data: data)
        : client.patch<Object?>('/api/welfare/case-types/$id/', data: data);
  }

  Future<Decimal> welfareYearlyContribution() async =>
      Money.parse((await client.get<Map<String, dynamic>>('/api/welfare/settings/'))['yearly_contribution']);

  Future<void> setWelfareYearlyContribution(Decimal amount) =>
      client.patch<Object?>('/api/welfare/settings/', data: {'yearly_contribution': amount.toStringAsFixed(2)});

  Future<List<WelfareCase>> welfareCases({String? status}) async =>
      ((await client.get<Object?>('/api/welfare/cases/', query: status == null ? null : {'status': status})) as List? ??
              const [])
          .whereType<Map<String, dynamic>>()
          .map(WelfareCase.fromJson)
          .toList();

  Future<WelfareCase> welfareCase(String id) async =>
      WelfareCase.fromJson(await client.get<Map<String, dynamic>>('/api/welfare/cases/$id/'));

  Future<List<WelfareContribution>> welfareCaseContributions(String id, {bool outstandingOnly = false}) async =>
      results(await client.get<Object?>(
        '/api/welfare/cases/$id/contributions/',
        query: outstandingOnly ? {'outstanding': 'true'} : null,
      )).map(WelfareContribution.fromJson).toList();

  Future<WelfareCase> openWelfareCase({
    required String caseTypeId,
    required String beneficiaryId,
    required String affectedPerson,
    required String description,
  }) async =>
      WelfareCase.fromJson(await client.post<Map<String, dynamic>>('/api/welfare/cases/', data: {
        'case_type': caseTypeId,
        'beneficiary': beneficiaryId,
        'affected_person': affectedPerson,
        'description': description,
      }));

  Future<WelfareCase> approveWelfareCase(String id, String notes) async => WelfareCase.fromJson(
      await client.post<Map<String, dynamic>>('/api/welfare/cases/$id/approve/', data: {'notes': notes}));

  Future<WelfareCase> rejectWelfareCase(String id, String notes) async => WelfareCase.fromJson(
      await client.post<Map<String, dynamic>>('/api/welfare/cases/$id/reject/', data: {'notes': notes}));

  Future<WelfareCase> closeWelfareCase(String id) async =>
      WelfareCase.fromJson(await client.post<Map<String, dynamic>>('/api/welfare/cases/$id/close/'));

  Future<WelfareCase> recordWelfarePayout({
    required String caseId,
    required Decimal amount,
    required String method,
    required DateTime paidOn,
    required String reference,
    required String paidTo,
  }) async =>
      WelfareCase.fromJson(await client.post<Map<String, dynamic>>('/api/welfare/cases/$caseId/payouts/', data: {
        'amount': amount.toStringAsFixed(2),
        'method': method,
        'paid_on': _isoDate(paidOn),
        'reference': reference,
        'paid_to': paidTo,
      }));

  Future<List<MemberBrief>> searchWelfareMembers(String query) async =>
      ((await client.get<Object?>('/api/welfare/members/search/', query: {'q': query})) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MemberBrief.fromJson)
          .toList();

  Future<MemberWelfare> memberWelfare(String memberId) async =>
      MemberWelfare.fromJson(await client.get<Map<String, dynamic>>('/api/welfare/members/$memberId/'));

  Future<MemberWelfare> recordWelfarePayment({
    required String memberId,
    required Decimal amount,
    required String method,
    required DateTime date,
    required String reference,
  }) async =>
      MemberWelfare.fromJson(await client.post<Map<String, dynamic>>('/api/welfare/members/$memberId/payments/', data: {
        'amount': amount.toStringAsFixed(2),
        'method': method,
        'transaction_date': _isoDate(date),
        'reference': reference,
      }));

  Future<void> closeWelfareYear(int year) => client.post<Object?>('/api/welfare/years/$year/close/');

  Future<Set<int>> closedWelfareYears() async =>
      ((await client.get<Object?>('/api/welfare/years/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((y) => (y['year'] as num).toInt())
          .toSet();

  Future<void> changePassword(String current, String next) => client.post<Object?>(
        '/api/auth/me/change-password/',
        data: {'current_password': current, 'new_password': next},
      );
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
