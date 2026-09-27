import 'package:decimal/decimal.dart';

import '../models/fines.dart';
import 'leader_api.dart' show isoDate;
import 'sacco_api.dart';

/// Fines: the register, charging, payments and waivers.
extension FinesApi on SaccoApi {
  Future<MemberFines> myFines() async =>
      MemberFines.fromJson(await client.get<Map<String, dynamic>>('/api/fines/me/'));

  Future<MemberFines> memberFines(String memberId) async =>
      MemberFines.fromJson(await client.get<Map<String, dynamic>>('/api/fines/members/$memberId/'));

  Future<FinesSummary> finesSummary() async =>
      FinesSummary.fromJson(await client.get<Map<String, dynamic>>('/api/fines/summary/'));

  Future<List<OffenceTypeItem>> offenceTypes() async =>
      ((await client.get<Object?>('/api/fines/offence-types/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OffenceTypeItem.fromJson)
          .toList();

  Future<void> saveOffenceType({
    String? id,
    required String name,
    required Decimal amount,
    String description = '',
    String fromAttendance = '',
    bool isActive = true,
  }) {
    final data = {
      'name': name,
      'amount': amount.toString(),
      'description': description,
      'from_attendance': fromAttendance,
      'is_active': isActive,
    };
    return id == null
        ? client.post<Object?>('/api/fines/offence-types/', data: data)
        : client.patch<Object?>('/api/fines/offence-types/$id/', data: data);
  }

  Future<void> chargeFine({
    required String memberId,
    required String offenceTypeId,
    required DateTime incurredOn,
    Decimal? amount,
    String? meetingId,
    String notes = '',
  }) =>
      client.post<Object?>('/api/fines/', data: {
        'member': memberId,
        'offence_type': offenceTypeId,
        'incurred_on': isoDate(incurredOn),
        'amount': ?amount?.toString(),
        'meeting': ?meetingId,
        'notes': notes,
      });

  Future<void> recordFinePayment({
    required String memberId,
    required Decimal amount,
    required String method,
    required DateTime paidOn,
    required String idempotencyKey,
    String reference = '',
  }) =>
      client.post<Object?>('/api/fines/payments/', data: {
        'member': memberId,
        'amount': amount.toString(),
        'method': method,
        'paid_on': isoDate(paidOn),
        'idempotency_key': idempotencyKey,
        'reference': reference,
      });

  /// One sitting: several members, each with their own amount. All or nothing.
  Future<int> chargeFinesInBulk({
    required String offenceTypeId,
    required DateTime incurredOn,
    required List<Map<String, dynamic>> entries,
    String notes = '',
    String? meetingId,
  }) async =>
      ((await client.post<Map<String, dynamic>>('/api/fines/bulk/', data: {
        'offence_type': offenceTypeId,
        'incurred_on': isoDate(incurredOn),
        'entries': entries,
        'notes': notes,
        'meeting': ?meetingId,
      }))['charged'] as num)
          .toInt();

  Future<void> waiveFine(String fineId, String reason) =>
      client.post<Object?>('/api/fines/$fineId/waive/', data: {'reason': reason});

  Future<List<FineProposal>> meetingFineProposals(String meetingId) async =>
      ((await client.get<Object?>('/api/fines/meetings/$meetingId/proposals/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FineProposal.fromJson)
          .toList();

  Future<int> chargeFinesFromMeeting(String meetingId, List<String> memberIds) async =>
      ((await client.post<Map<String, dynamic>>('/api/fines/meetings/$meetingId/proposals/',
              data: {'members': memberIds}))['charged'] as num)
          .toInt();
}
