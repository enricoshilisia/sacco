import 'package:dio/dio.dart';

import '../models/models.dart';
import '../models/profile.dart';
import 'api_client.dart';
import 'leader_api.dart' show isoDate;
import 'sacco_api.dart';

/// Member profile, family register, documents and the approval queue.
extension ProfileApi on SaccoApi {
  Future<MyProfile> myProfile() async =>
      MyProfile.fromJson(await client.get<Map<String, dynamic>>('/api/members/me/profile/'));

  /// Protected personal details - sent for approval, not applied directly.
  /// An empty [changes] submits the profile as it is for first approval.
  Future<MyProfile> submitProfileChanges(Map<String, dynamic> changes, {String note = ''}) async =>
      MyProfile.fromJson(await client.post<Map<String, dynamic>>('/api/members/me/profile/changes/', data: {
        'changes': _encode(changes),
        'note': note,
      }));

  /// Basic details members update freely (email, address, occupation...).
  Future<Member> updateMyBasics(Map<String, dynamic> fields) async =>
      Member.fromJson(await client.patch<Map<String, dynamic>>('/api/members/me/', data: fields));

  Future<MyProfile> addFamilyMember(Map<String, dynamic> data, {String note = ''}) async => MyProfile.fromJson(
      await client.post<Map<String, dynamic>>('/api/members/me/family/', data: {..._encode(data), 'note': note}));

  Future<MyProfile> updateFamilyMember(String id, Map<String, dynamic> changes, {String note = ''}) async =>
      MyProfile.fromJson(await client.patch<Map<String, dynamic>>(
        '/api/members/me/family/$id/',
        data: {..._encode(changes), 'note': note},
      ));

  Future<MyProfile> removeFamilyMember(String id, {String note = ''}) async {
    try {
      final response = await client.dio.delete('/api/members/me/family/$id/', data: {'note': note});
      return MyProfile.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<MyProfile> cancelChangeRequest(String id) async =>
      MyProfile.fromJson(await client.post<Map<String, dynamic>>('/api/members/me/change-requests/$id/cancel/'));

  /// Uploads an ID scan / certificate. [ocrIdNumber] is what the phone read
  /// off an ID scan (guidance for the approver).
  Future<MemberDocumentItem> uploadDocument({
    required String filePath,
    required String documentType,
    String? familyMemberId,
    String ocrIdNumber = '',
  }) async {
    final isPdf = filePath.toLowerCase().endsWith('.pdf');
    final form = FormData.fromMap({
      'document_type': documentType,
      'file': await MultipartFile.fromFile(filePath, filename: isPdf ? 'document.pdf' : 'document.jpg'),
      'family_member': ?familyMemberId,
      'ocr_id_number': ocrIdNumber,
    });
    return MemberDocumentItem.fromJson(await client.post<Map<String, dynamic>>('/api/members/me/documents/', data: form));
  }

  // --- Approvers (Secretary) --------------------------------------------------

  Future<List<ChangeRequestItem>> changeRequests({String status = 'PENDING'}) async =>
      results(await client.get<Object?>('/api/members/change-requests/', query: {'status': status}))
          .map(ChangeRequestItem.fromJson)
          .toList();

  Future<void> approveChangeRequest(String id, {String notes = ''}) =>
      client.post<Object?>('/api/members/change-requests/$id/approve/', data: {'notes': notes});

  Future<void> rejectChangeRequest(String id, String notes) =>
      client.post<Object?>('/api/members/change-requests/$id/reject/', data: {'notes': notes});

  Future<List<FamilyPerson>> memberFamily(String memberId) async =>
      ((await client.get<Object?>('/api/members/$memberId/family/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FamilyPerson.fromJson)
          .toList();

  Future<List<MemberDocumentItem>> memberDocuments(String memberId) async =>
      ((await client.get<Object?>('/api/members/$memberId/documents/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MemberDocumentItem.fromJson)
          .toList();

  /// For opening a welfare case: the member's approved, living family.
  Future<List<FamilyPerson>> welfareFamily(String memberId) async =>
      ((await client.get<Object?>('/api/welfare/members/$memberId/family/')) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FamilyPerson.fromJson)
          .toList();
}

Map<String, dynamic> _encode(Map<String, dynamic> values) =>
    values.map((k, v) => MapEntry(k, v is DateTime ? isoDate(v) : v));
