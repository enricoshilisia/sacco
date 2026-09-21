import '../../l10n/app_localizations.dart';

// Backend codes -> translated labels for profile/family screens.

String fieldLabel(AppLocalizations l, String field) => switch (field) {
      'first_name' => l.fieldFirstName,
      'last_name' => l.fieldLastName,
      'other_names' => l.fieldOtherNames,
      'date_of_birth' => l.fieldDateOfBirth,
      'gender' => l.fieldGender,
      'id_type' => l.fieldIdType,
      'id_number' => l.idNumber,
      'phone_number' => l.phoneNumber,
      'marital_status' => l.fieldMaritalStatus,
      'relationship' => l.fieldRelationship,
      'full_name' => l.fieldFullName,
      'birth_certificate_number' => l.fieldBirthCert,
      'is_next_of_kin' => l.fieldNextOfKin,
      'is_deceased' => l.fieldDeceased,
      'email' => l.email,
      'physical_address' => l.address,
      'occupation' => l.fieldOccupation,
      'employer' => l.fieldEmployer,
      'county' => l.fieldCounty,
      _ => field,
    };

String relationshipLabel(AppLocalizations l, String code) => switch (code) {
      'SPOUSE' => l.relSpouse,
      'CHILD' => l.relChild,
      'PARENT' => l.relParent,
      'PARENT_IN_LAW' => l.relParentInLaw,
      'SIBLING' => l.relSibling,
      'SELF' => l.relSelf,
      _ => code,
    };

String genderLabel(AppLocalizations l, String code) => switch (code) {
      'FEMALE' => l.genderFemale,
      'MALE' => l.genderMale,
      'OTHER' => l.genderOther,
      _ => code,
    };

String maritalLabel(AppLocalizations l, String code) => switch (code) {
      'SINGLE' => l.maritalSingle,
      'MARRIED' => l.maritalMarried,
      'WIDOWED' => l.maritalWidowed,
      'DIVORCED' => l.maritalDivorced,
      _ => code,
    };

String idTypeLabel(AppLocalizations l, String code) => switch (code) {
      'NATIONAL_ID' => l.idTypeNational,
      'HUDUMA' => l.idTypeHuduma,
      'NIDA' => l.idTypeNida,
      'PASSPORT' => l.idTypePassport,
      _ => code,
    };

/// Human-readable value for a field (dates, choices, yes/no).
String fieldValue(AppLocalizations l, String field, Object? value) {
  if (value == null || value == '') return '—';
  if (value is bool) return value ? l.yes : l.no;
  final text = value.toString();
  return switch (field) {
    'gender' => genderLabel(l, text),
    'marital_status' => maritalLabel(l, text),
    'relationship' => relationshipLabel(l, text),
    'id_type' => idTypeLabel(l, text),
    _ => text,
  };
}
