import 'models.dart';

// Member profile, family register, KYC documents and change requests.
// Mirrors backend/members/profile_serializers.py.

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
String _str(Object? v) => v?.toString() ?? '';
List<Map<String, dynamic>> _list(Object? v) => v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

const familyRelationships = ['SPOUSE', 'CHILD', 'PARENT', 'PARENT_IN_LAW', 'SIBLING'];

class FamilyPerson {
  final String id;
  final String relationship;
  final String relationshipLabel;
  final String fullName;
  final DateTime? dateOfBirth;
  final int? age;
  final String gender;
  final String idNumber;
  final String birthCertificateNumber;
  final String phoneNumber;
  final bool isNextOfKin;
  final bool isDeceased;
  final String status; // PENDING / APPROVED / REJECTED / REMOVED

  FamilyPerson.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        relationship = _str(j['relationship']),
        relationshipLabel = _str(j['relationship_label']),
        fullName = _str(j['full_name']),
        dateOfBirth = _date(j['date_of_birth']),
        age = (j['age'] as num?)?.toInt(),
        gender = _str(j['gender']),
        idNumber = _str(j['id_number']),
        birthCertificateNumber = _str(j['birth_certificate_number']),
        phoneNumber = _str(j['phone_number']),
        isNextOfKin = j['is_next_of_kin'] == true,
        isDeceased = j['is_deceased'] == true,
        status = _str(j['status']);

  bool get isApproved => status == 'APPROVED';
}

class MemberDocumentItem {
  final String id;
  final String documentType;
  final String documentTypeLabel;
  final String? familyMemberId;
  final String familyMemberName;
  final String fileUrl;
  final String ocrIdNumber;
  final bool? idNumberMatch;
  final DateTime? uploadedAt;

  MemberDocumentItem.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        documentType = _str(j['document_type']),
        documentTypeLabel = _str(j['document_type_label']),
        familyMemberId = j['family_member'] as String?,
        familyMemberName = _str(j['family_member_name']),
        fileUrl = _str(j['file']),
        ocrIdNumber = _str(j['ocr_id_number']),
        idNumberMatch = j['id_number_match'] as bool?,
        uploadedAt = _date(j['uploaded_at']);

  bool get isPdf => fileUrl.toLowerCase().contains('.pdf');
}

class ChangeRequestItem {
  final String id;
  final String target; // PROFILE / FAMILY_ADD / FAMILY_UPDATE / FAMILY_REMOVE
  final String targetLabel;
  final String status;
  final String statusLabel;
  final String memberId;
  final String memberNumber;
  final String memberName;
  final String memberProfileStatus;
  final FamilyPerson? familyMember;
  final Map<String, dynamic> changes;
  final Map<String, dynamic> before;
  final Map<String, dynamic> current;
  final String note;
  final DateTime? submittedAt;
  final String decidedBy;
  final String decisionNotes;
  final List<MemberDocumentItem> documents;

  ChangeRequestItem.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        target = _str(j['target']),
        targetLabel = _str(j['target_label']),
        status = _str(j['status']),
        statusLabel = _str(j['status_label']),
        memberId = _str(j['member_id']),
        memberNumber = _str(j['member_number']),
        memberName = _str(j['member_name']),
        memberProfileStatus = _str(j['member_profile_status']),
        familyMember = j['family_member'] is Map<String, dynamic>
            ? FamilyPerson.fromJson(j['family_member'] as Map<String, dynamic>)
            : null,
        changes = (j['changes'] as Map?)?.cast<String, dynamic>() ?? const {},
        before = (j['before'] as Map?)?.cast<String, dynamic>() ?? const {},
        current = (j['current'] as Map?)?.cast<String, dynamic>() ?? const {},
        note = _str(j['note']),
        submittedAt = _date(j['submitted_at']),
        decidedBy = _str(j['decided_by_name']),
        decisionNotes = _str(j['decision_notes']),
        documents = _list(j['documents']).map(MemberDocumentItem.fromJson).toList();

  bool get isPending => status == 'PENDING';
}

/// GET /api/members/me/profile/
class MyProfile {
  final Member member;
  final List<FamilyPerson> family;
  final List<ChangeRequestItem> requests;
  final List<MemberDocumentItem> documents;

  MyProfile.fromJson(Map<String, dynamic> j)
      : member = Member.fromJson((j['member'] as Map<String, dynamic>?) ?? const {}),
        family = _list(j['family']).map(FamilyPerson.fromJson).toList(),
        requests = _list(j['requests']).map(ChangeRequestItem.fromJson).toList(),
        documents = _list(j['documents']).map(MemberDocumentItem.fromJson).toList();

  List<ChangeRequestItem> get pending => requests.where((r) => r.isPending).toList();
  bool get hasPendingProfileChange => pending.any((r) => r.target == 'PROFILE');

  MemberDocumentItem? documentFor(String type, {String? familyMemberId}) {
    for (final d in documents) {
      if (d.documentType == type && d.familyMemberId == familyMemberId) return d;
    }
    return null;
  }
}
