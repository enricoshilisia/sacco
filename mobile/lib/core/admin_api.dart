import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../models/admin.dart';
import '../models/models.dart' show results;
import 'api_client.dart';
import 'leader_api.dart' show isoDate;
import 'sacco_api.dart';

/// Admin support (users, passwords, positions, audit log) and member
/// admission (applications, registration fee, verification).
extension AdminApi on SaccoApi {
  // --- Users & support -------------------------------------------------------

  Future<List<AdminUser>> users({String search = '', String? role, bool disabledOnly = false}) async =>
      ((await client.get<Object?>('/api/tenant/users/', query: {
        if (search.isNotEmpty) 'search': search,
        'role': ?role,
        if (disabledOnly) 'disabled': '1',
      })) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminUser.fromJson)
          .toList();

  Future<AdminUser> user(String id) async =>
      AdminUser.fromJson(await client.get<Map<String, dynamic>>('/api/tenant/users/$id/'));

  /// The temporary password, shown once to hand to the person.
  Future<String> resetPassword(String userId) async =>
      (await client.post<Map<String, dynamic>>('/api/tenant/users/$userId/reset-password/'))['temporary_password']
          as String;

  Future<void> setLoginEnabled(String userId, bool enabled) =>
      client.post<Object?>('/api/tenant/users/$userId/${enabled ? 'enable' : 'disable'}/');

  Future<List<({String membershipId, String roleName, String jobTitle, bool automatic})>> userPositions(
          String userId) async =>
      ((await client.get<Object?>('/api/tenant/users/$userId/positions/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((m) => (
                membershipId: m['membership_id'].toString(),
                roleName: m['role_name'].toString(),
                jobTitle: (m['job_title'] ?? '').toString(),
                automatic: m['automatic'] == true,
              ))
          .toList();

  // --- Positions -------------------------------------------------------------

  Future<List<Position>> positions() async =>
      ((await client.get<Object?>('/api/tenant/positions/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Position.fromJson)
          .toList();

  Future<void> assignPosition(String roleId, {String? userId, String? memberId, String jobTitle = ''}) =>
      client.post<Object?>('/api/tenant/positions/$roleId/assign/', data: {
        'user_id': ?userId,
        'member_id': ?memberId,
        'job_title': jobTitle,
      });

  Future<void> removeFromPosition(String membershipId) =>
      client.post<Object?>('/api/tenant/memberships/$membershipId/remove/');

  Future<void> createPosition({
    required String name,
    String description = '',
    int? maxHolders,
    String? copyFrom,
    String? assistantOf,
  }) =>
      client.post<Object?>('/api/tenant/positions/', data: {
        'name': name,
        'description': description,
        'max_holders': maxHolders,
        'copy_from': ?copyFrom,
        'assistant_of': ?assistantOf,
      });

  // --- Audit log ---------------------------------------------------------------

  Future<({List<AuditEventItem> items, bool hasMore})> auditEvents({
    int page = 1,
    String search = '',
    String? userId,
    bool securityOnly = false,
    DateTime? from,
    DateTime? to,
  }) async {
    final body = await client.get<Object?>('/api/audit/events/', query: _auditQuery(
      page: page, search: search, userId: userId, securityOnly: securityOnly, from: from, to: to,
    ));
    final items = results(body).map(AuditEventItem.fromJson).toList();
    return (items: items, hasMore: body is Map && body['next'] != null);
  }

  Future<Uint8List> auditCsv({String search = '', String? userId, bool securityOnly = false, DateTime? from, DateTime? to}) async {
    try {
      final response = await client.dio.get<List<int>>(
        '/api/audit/events/',
        queryParameters: {
          ..._auditQuery(search: search, userId: userId, securityOnly: securityOnly, from: from, to: to),
          'export': 'csv',
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    } catch (e) {
      throw toApiException(e);
    }
  }

  Map<String, dynamic> _auditQuery({
    int? page,
    String search = '',
    String? userId,
    bool securityOnly = false,
    DateTime? from,
    DateTime? to,
  }) =>
      {
        'page': ?page,
        if (search.isNotEmpty) 'q': search,
        'user': ?userId,
        if (securityOnly) 'security': '1',
        if (from != null) 'from': isoDate(from),
        if (to != null) 'to': isoDate(to),
      };

  // --- Admission ---------------------------------------------------------------

  Future<List<MemberApplicationItem>> applications({String status = 'PENDING'}) async =>
      ((await client.get<Object?>('/api/members/applications/', query: {'status': status})) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MemberApplicationItem.fromJson)
          .toList();

  Future<MemberApplicationItem> submitApplication(Map<String, dynamic> data) async => MemberApplicationItem.fromJson(
      await client.post<Map<String, dynamic>>('/api/members/applications/', data: {
        for (final e in data.entries) e.key: e.value is DateTime ? isoDate(e.value as DateTime) : e.value,
      }));

  Future<MemberApplicationItem> approveApplication(String id, {String notes = ''}) async =>
      MemberApplicationItem.fromJson(
          await client.post<Map<String, dynamic>>('/api/members/applications/$id/approve/', data: {'notes': notes}));

  Future<void> rejectApplication(String id, String reason) =>
      client.post<Object?>('/api/members/applications/$id/reject/', data: {'reason': reason});

  Future<void> cancelApplication(String id) => client.post<Object?>('/api/members/applications/$id/cancel/');

  Future<Verification> myVerification() async =>
      Verification.fromJson(await client.get<Map<String, dynamic>>('/api/members/me/verification/'));

  Future<Verification> memberVerification(String memberId) async =>
      Verification.fromJson(await client.get<Map<String, dynamic>>('/api/members/$memberId/verification/'));

  Future<Verification> recordRegistrationFee(
    String memberId, {
    required Decimal amount,
    required String method,
    required DateTime paidOn,
    required String idempotencyKey,
    String reference = '',
  }) async =>
      Verification.fromJson(await client.post<Map<String, dynamic>>('/api/members/$memberId/registration-fee/', data: {
        'amount': amount.toString(),
        'method': method,
        'paid_on': isoDate(paidOn),
        'reference': reference,
        'idempotency_key': idempotencyKey,
      }));

  Future<MembershipRules> membershipRules() async =>
      MembershipRules.fromJson(await client.get<Map<String, dynamic>>('/api/members/membership-settings/'));

  Future<MembershipRules> updateMembershipRules({Decimal? registrationFee, int? verificationMonths}) async =>
      MembershipRules.fromJson(await client.patch<Map<String, dynamic>>('/api/members/membership-settings/', data: {
        if (registrationFee != null) 'registration_fee': registrationFee.toString(),
        'verification_months': ?verificationMonths,
      }));
}
