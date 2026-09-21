import '../l10n/app_localizations.dart';
import 'common.dart';

// Backend enum code -> translated label + chip tone. Unknown codes fall
// back to the raw value so a new backend status never crashes the app.

(String, Tone) loanStatus(AppLocalizations l, String code) => switch (code) {
      'PENDING_GUARANTORS' => (l.loanStatusPENDING_GUARANTORS, Tone.warn),
      'PENDING_APPRAISAL' => (l.loanStatusPENDING_APPRAISAL, Tone.warn),
      'APPRAISED' => (l.loanStatusAPPRAISED, Tone.warn),
      'APPROVED' => (l.loanStatusAPPROVED, Tone.good),
      'REJECTED' => (l.loanStatusREJECTED, Tone.bad),
      'DISBURSED' => (l.loanStatusDISBURSED, Tone.warn),
      'ACTIVE' => (l.loanStatusACTIVE, Tone.good),
      'CLOSED' => (l.loanStatusCLOSED, Tone.neutral),
      'DEFAULTED' => (l.loanStatusDEFAULTED, Tone.bad),
      _ => (code, Tone.neutral),
    };

(String, Tone) guarantorStatus(AppLocalizations l, String code) => switch (code) {
      'PENDING' => (l.guarantorStatusPENDING, Tone.warn),
      'CONSENTED' => (l.guarantorStatusCONSENTED, Tone.good),
      'DECLINED' => (l.guarantorStatusDECLINED, Tone.bad),
      'RELEASED' => (l.guarantorStatusRELEASED, Tone.neutral),
      _ => (code, Tone.neutral),
    };

(String, Tone) collectionStatus(AppLocalizations l, String code) => switch (code) {
      'PENDING' => (l.statusPENDING, Tone.warn),
      'SUCCESS' => (l.statusSUCCESS, Tone.good),
      'FAILED' => (l.statusFAILED, Tone.bad),
      'CANCELLED' => (l.statusCANCELLED, Tone.neutral),
      _ => (code, Tone.neutral),
    };

(String, Tone) entryStatus(AppLocalizations l, String code) => switch (code) {
      'PROPOSED' => (l.entryStatusPROPOSED, Tone.warn),
      'POSTED' => (l.entryStatusPOSTED, Tone.good),
      'PAID' => (l.entryStatusPAID, Tone.good),
      _ => (code, Tone.neutral),
    };

String purposeLabel(AppLocalizations l, String code) => switch (code) {
      'SAVINGS_DEPOSIT' => l.purposeSAVINGS_DEPOSIT,
      'SHARE_CONTRIBUTION' => l.purposeSHARE_CONTRIBUTION,
      'WELFARE_CONTRIBUTION' => l.purposeWELFARE_CONTRIBUTION,
      _ => code,
    };

String txLabel(AppLocalizations l, String code) => switch (code) {
      'DEPOSIT' => l.txDEPOSIT,
      'WITHDRAWAL' => l.txWITHDRAWAL,
      'CONTRIBUTION' => l.txCONTRIBUTION,
      _ => code,
    };

String interestMethod(AppLocalizations l, String code) => switch (code) {
      'REDUCING_BALANCE' => l.methodREDUCING_BALANCE,
      'FLAT' => l.methodFLAT,
      _ => code,
    };

(String, Tone) welfareCaseStatus(AppLocalizations l, String code) => switch (code) {
      'PENDING_APPROVAL' => (l.welfareStatusPENDING_APPROVAL, Tone.warn),
      'APPROVED' => (l.welfareStatusAPPROVED, Tone.good),
      'REJECTED' => (l.welfareStatusREJECTED, Tone.bad),
      'CLOSED' => (l.welfareStatusCLOSED, Tone.neutral),
      _ => (code, Tone.neutral),
    };

String paymentMethod(AppLocalizations l, String code) => switch (code) {
      'CASH' => l.methodCash,
      'BANK' => l.methodBank,
      'MOBILE_MONEY' => l.methodMobileMoney,
      _ => code,
    };
