// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appTitle => 'Inuka West';

  @override
  String get retry => 'Jaribu tena';

  @override
  String get cancel => 'Ghairi';

  @override
  String get done => 'Sawa';

  @override
  String get save => 'Hifadhi';

  @override
  String get saved => 'Imehifadhiwa';

  @override
  String get networkError =>
      'Imeshindikana kufikia seva. Angalia mtandao wako na ujaribu tena.';

  @override
  String get genericError => 'Hitilafu imetokea. Tafadhali jaribu tena.';

  @override
  String get findSaccoTitle => 'Tafuta SACCO yako';

  @override
  String get findSaccoBody =>
      'Weka msimbo uliopewa na SACCO yako. Ni sehemu ya kwanza ya anwani yake ya wavuti, mfano \"shirika\".';

  @override
  String get saccoCode => 'Msimbo wa SACCO';

  @override
  String get saccoNotFound => 'Hakuna SACCO yenye msimbo huo.';

  @override
  String get continueLabel => 'Endelea';

  @override
  String get loginTitle => 'Ingia';

  @override
  String get phoneNumber => 'Nambari ya simu';

  @override
  String get phoneHint => '+2557...';

  @override
  String get password => 'Nenosiri';

  @override
  String get loginSubmit => 'Ingia';

  @override
  String get loginError =>
      'Kuingia kumeshindwa. Angalia taarifa zako na ujaribu tena.';

  @override
  String get sessionExpired =>
      'Muda wako wa kuingia umeisha. Tafadhali ingia tena.';

  @override
  String get noMemberRecord =>
      'Kuingia huku hakuna rekodi ya mwanachama wala huduma za wafanyakazi kwenye simu. Muombe msimamizi wa SACCO akupe jukumu.';

  @override
  String get notYourSacco => 'Si SACCO yako?';

  @override
  String get changeSacco => 'Badilisha SACCO';

  @override
  String get unlockTitle => 'Fungua';

  @override
  String get unlockReason => 'Fungua akaunti yako ya SACCO';

  @override
  String get unlockButton => 'Fungua';

  @override
  String get usePassword => 'Ingia kwa nenosiri badala yake';

  @override
  String get navHome => 'Nyumbani';

  @override
  String get navSavings => 'Akiba';

  @override
  String get navLoans => 'Mikopo';

  @override
  String get navProfile => 'Wasifu';

  @override
  String welcome(String name) {
    return 'Karibu, $name';
  }

  @override
  String memberNumber(String number) {
    return 'Mwanachama na. $number';
  }

  @override
  String get shareCapital => 'Mtaji wa hisa';

  @override
  String get shareCapitalHelp =>
      'Umiliki wako. Hupata gawio; hauwezi kutolewa.';

  @override
  String get savingsTotal => 'Akiba';

  @override
  String get savingsHelp =>
      'Amana zinazoweza kutolewa. Hupata riba na huamua kiasi unachoweza kukopa.';

  @override
  String get loanOutstanding => 'Salio la mkopo';

  @override
  String get noActiveLoans => 'Hakuna mikopo inayoendelea';

  @override
  String nextPayment(String amount, String date) {
    return 'Malipo yajayo $amount tarehe $date';
  }

  @override
  String overdue(int days, String amount) {
    return 'Imechelewa siku $days · $amount';
  }

  @override
  String get quickActions => 'Huduma za haraka';

  @override
  String get actionDeposit => 'Weka akiba';

  @override
  String get actionContribute => 'Nunua hisa';

  @override
  String get actionApply => 'Omba mkopo';

  @override
  String get actionDividends => 'Gawio';

  @override
  String guaranteeRequestsBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wanachama $count wamekuomba udhamini mikopo yao',
      one: 'Mwanachama 1 amekuomba udhamini mkopo wake',
    );
    return '$_temp0';
  }

  @override
  String get recentPayments => 'Malipo ya pesa kwa simu ya hivi karibuni';

  @override
  String get savingsTitle => 'Akiba na hisa';

  @override
  String get savingsAccounts => 'Akaunti za akiba';

  @override
  String get noSavingsAccounts =>
      'Hakuna akaunti za akiba bado. Weka akiba kufungua moja.';

  @override
  String get contributions => 'Michango';

  @override
  String get transactions => 'Miamala';

  @override
  String get noTransactions => 'Hakuna miamala bado.';

  @override
  String get txDEPOSIT => 'Amana';

  @override
  String get txWITHDRAWAL => 'Utoaji';

  @override
  String get txCONTRIBUTION => 'Mchango wa hisa';

  @override
  String get withdrawalsAtBranch => 'Utoaji hushughulikiwa na SACCO yako.';

  @override
  String pledgedLocked(String amount) {
    return '$amount imefungwa kama dhamana ya mikopo ya wanachama wengine';
  }

  @override
  String get payTitleDeposit => 'Weka akiba';

  @override
  String get payTitleContribute => 'Nunua hisa';

  @override
  String get savingsProduct => 'Bidhaa ya akiba';

  @override
  String get selectProduct => 'Chagua bidhaa';

  @override
  String get amount => 'Kiasi';

  @override
  String get amountInvalid =>
      'Weka kiasi zaidi ya 0 chenye desimali 2 au chache.';

  @override
  String get payFromPhone => 'Lipa kutoka nambari ya simu';

  @override
  String get mobileMoneyHelp =>
      'Utapokea ombi la pesa kwa simu kwenye simu hii kuthibitisha.';

  @override
  String get payButton => 'Tuma ombi la malipo';

  @override
  String get payWaiting => 'Angalia simu yako na uweke PIN kuthibitisha…';

  @override
  String get paySuccess => 'Malipo yamepokelewa';

  @override
  String get payFailed => 'Malipo yameshindikana';

  @override
  String get payCancelled => 'Malipo yameghairiwa';

  @override
  String get payStillPending =>
      'Bado inasubiri uthibitisho. Itaonekana kwenye taarifa yako mtoa huduma akithibitisha.';

  @override
  String receipt(String receipt) {
    return 'Risiti $receipt';
  }

  @override
  String get statusPENDING => 'Inasubiri';

  @override
  String get statusSUCCESS => 'Imefanikiwa';

  @override
  String get statusFAILED => 'Imeshindikana';

  @override
  String get statusCANCELLED => 'Imeghairiwa';

  @override
  String get purposeSAVINGS_DEPOSIT => 'Amana ya akiba';

  @override
  String get purposeSHARE_CONTRIBUTION => 'Mchango wa hisa';

  @override
  String get loansTitle => 'Mikopo';

  @override
  String get myLoans => 'Mikopo yangu';

  @override
  String get noLoans => 'Bado hujaomba mkopo.';

  @override
  String get guaranteeRequests => 'Maombi ya udhamini';

  @override
  String guaranteeFor(String name, String amount) {
    return '$name anakuomba uweke dhamana ya $amount';
  }

  @override
  String get guaranteeWarning =>
      'Ukikubali, kiasi hiki cha amana zako kitafungwa hadi mkopo wake ulipwe. Hutaweza kukitoa wala kukopa dhidi yake.';

  @override
  String get accept => 'Kubali';

  @override
  String get decline => 'Kataa';

  @override
  String get confirmAcceptTitle => 'Weka amana zako kama dhamana?';

  @override
  String get loanStatusPENDING_GUARANTORS => 'Inasubiri wadhamini';

  @override
  String get loanStatusPENDING_APPRAISAL => 'Inasubiri tathmini';

  @override
  String get loanStatusAPPRAISED => 'Imetathminiwa';

  @override
  String get loanStatusAPPROVED => 'Imeidhinishwa';

  @override
  String get loanStatusREJECTED => 'Imekataliwa';

  @override
  String get loanStatusDISBURSED => 'Utoaji unasubiri';

  @override
  String get loanStatusACTIVE => 'Inaendelea';

  @override
  String get loanStatusCLOSED => 'Imelipwa';

  @override
  String get loanStatusDEFAULTED => 'Imeshindwa kulipwa';

  @override
  String get guarantorStatusPENDING => 'Inasubiri';

  @override
  String get guarantorStatusCONSENTED => 'Amekubali';

  @override
  String get guarantorStatusDECLINED => 'Amekataa';

  @override
  String get guarantorStatusRELEASED => 'Ameachiliwa';

  @override
  String termMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Miezi $months',
      one: 'Mwezi 1',
    );
    return '$_temp0';
  }

  @override
  String get applyTitle => 'Omba mkopo';

  @override
  String get loanProduct => 'Bidhaa ya mkopo';

  @override
  String productTerms(
    String rate,
    String method,
    int min,
    int max,
    String multiple,
  ) {
    return '$rate% · $method · miezi $min–$max · hadi mara $multiple ya amana';
  }

  @override
  String get methodREDUCING_BALANCE => 'salio linalopungua';

  @override
  String get methodFLAT => 'tambarare';

  @override
  String get term => 'Muda (miezi)';

  @override
  String termInvalid(int min, int max) {
    return 'Weka muda kati ya miezi $min na $max.';
  }

  @override
  String get purpose => 'Madhumuni (hiari)';

  @override
  String get applySubmit => 'Wasilisha ombi';

  @override
  String get applied => 'Ombi limeundwa. Sasa ongeza wadhamini wako.';

  @override
  String get loanDetail => 'Maelezo ya mkopo';

  @override
  String get requested => 'Kilichoombwa';

  @override
  String get interest => 'Riba';

  @override
  String get outstanding => 'Salio';

  @override
  String get guarantors => 'Wadhamini';

  @override
  String get noGuarantors => 'Hakuna wadhamini bado.';

  @override
  String guarantorsNeeded(int count) {
    return 'Bidhaa hii inahitaji angalau wadhamini $count waliokubali.';
  }

  @override
  String get addGuarantor => 'Ongeza mdhamini';

  @override
  String get guarantorMemberNumber => 'Nambari ya mwanachama wa mdhamini';

  @override
  String get pledgedAmount => 'Kiasi cha dhamana';

  @override
  String get add => 'Ongeza';

  @override
  String get submitForAppraisal => 'Wasilisha kwa tathmini';

  @override
  String get submitted => 'Imewasilishwa kwa tathmini';

  @override
  String get schedule => 'Ratiba ya marejesho';

  @override
  String installment(int n, String date) {
    return '#$n · tarehe $date';
  }

  @override
  String get paid => 'Imelipwa';

  @override
  String get repayments => 'Marejesho';

  @override
  String get automatedDecision => 'Uamuzi wa kiotomatiki';

  @override
  String get decisionNotes => 'Maelezo ya uamuzi';

  @override
  String get repayHelp =>
      'Kulipa, tumia njia ya kawaida ya marejesho ya SACCO yako. Kulipa mkopo ndani ya programu kunakuja hivi karibuni.';

  @override
  String get dividendsTitle => 'Gawio na riba';

  @override
  String get noDistributions => 'Hakuna malipo ya gawio au riba bado.';

  @override
  String get kindDIVIDEND => 'Gawio la hisa';

  @override
  String get kindINTEREST => 'Riba ya akiba';

  @override
  String get gross => 'Jumla';

  @override
  String get wht => 'Kodi ya zuio';

  @override
  String get net => 'Halisi';

  @override
  String get entryStatusPROPOSED => 'Imependekezwa';

  @override
  String get entryStatusPOSTED => 'Imewekwa';

  @override
  String get entryStatusPAID => 'Imelipwa';

  @override
  String get profileTitle => 'Wasifu wangu';

  @override
  String get kycVerified => 'KYC imethibitishwa';

  @override
  String get kycPending => 'KYC inasubiri';

  @override
  String get idNumber => 'Nambari ya kitambulisho';

  @override
  String get contactDetails => 'Mawasiliano';

  @override
  String get email => 'Barua pepe';

  @override
  String get address => 'Anwani ya makazi';

  @override
  String get kycLockedHelp =>
      'Jina na kitambulisho vinatoka kwenye rekodi yako ya KYC. Wasiliana na SACCO yako kuvirekebisha.';

  @override
  String get security => 'Usalama';

  @override
  String get biometricUnlock => 'Fungua kwa alama ya kidole / uso';

  @override
  String get biometricUnavailable => 'Haipatikani kwenye kifaa hiki';

  @override
  String get changePassword => 'Badilisha nenosiri';

  @override
  String get currentPassword => 'Nenosiri la sasa';

  @override
  String get newPassword => 'Nenosiri jipya';

  @override
  String get confirmPassword => 'Thibitisha nenosiri jipya';

  @override
  String get passwordTooShort => 'Tumia angalau herufi 8.';

  @override
  String get passwordMismatch => 'Manenosiri mapya hayafanani.';

  @override
  String get passwordChanged => 'Nenosiri limebadilishwa';

  @override
  String get language => 'Lugha';

  @override
  String get logout => 'Toka';

  @override
  String get required => 'Inahitajika';

  @override
  String get active => 'Hai';

  @override
  String get inactive => 'Haitumiki';

  @override
  String get all => 'Zote';

  @override
  String get approve => 'Idhinisha';

  @override
  String get reject => 'Kataa';

  @override
  String get methodCash => 'Taslimu';

  @override
  String get methodBank => 'Benki';

  @override
  String get methodMobileMoney => 'Pesa kwa simu';

  @override
  String get myRoles => 'Majukumu yangu';

  @override
  String get navWelfare => 'Ustawi';

  @override
  String get searchMemberHint => 'Jina, nambari ya mwanachama au simu';

  @override
  String get noMembersFound => 'Hakuna wanachama waliopatikana.';

  @override
  String get payTitleWelfare => 'Lipa ustawi';

  @override
  String get purposeWELFARE_CONTRIBUTION => 'Mchango wa ustawi';

  @override
  String get welfareTitle => 'Ustawi';

  @override
  String get welfareMine => 'Ustawi wangu';

  @override
  String get welfareCases => 'Kesi';

  @override
  String get welfareCounter => 'Kaunta';

  @override
  String get welfareRules => 'Kanuni';

  @override
  String get welfarePay => 'Lipa ustawi';

  @override
  String get welfarePayHelp =>
      'Hulipa kwanza deni lako la kesi zilizopita; kinachobaki huenda kwenye salio lako la ustawi la mwaka.';

  @override
  String get welfareBalance => 'Salio la ustawi';

  @override
  String get welfareBalanceHelp =>
      'Mchango wako wa mwaka ambao bado haujatumika. Michango ya kesi huchukuliwa hapa kwanza.';

  @override
  String welfareYearly(int year) {
    return 'Uliolipwa $year';
  }

  @override
  String get welfareOwed => 'Deni lako';

  @override
  String welfareOwedBanner(String amount) {
    return 'Unadaiwa $amount ya michango ya ustawi';
  }

  @override
  String get welfareContributions => 'Michango ya kesi';

  @override
  String get welfareNoContributions => 'Hakuna michango ya ustawi bado.';

  @override
  String welfareStillOwed(String amount) {
    return 'Deni $amount';
  }

  @override
  String get welfarePayments => 'Malipo';

  @override
  String welfareToDues(String amount) {
    return '$amount kwa madeni';
  }

  @override
  String welfareToBalance(String amount) {
    return '$amount kwa salio';
  }

  @override
  String get welfareYearlyAmount => 'Mchango wa ustawi wa mwaka';

  @override
  String get welfareCaseTypes => 'Aina za kesi';

  @override
  String get welfareRulesHelp =>
      'Kutoka katiba: kiasi kila mwanachama anachochangia kwa kila aina ya kesi.';

  @override
  String get welfareNoRules => 'Hakuna kanuni za ustawi bado.';

  @override
  String get welfareBeneficiaryContributes => 'Mwanachama husika pia huchangia';

  @override
  String get welfarePerMember => 'kwa kila mwanachama';

  @override
  String welfarePerMemberAmount(String amount) {
    return '$amount kwa kila mwanachama';
  }

  @override
  String get welfareAddRule => 'Ongeza aina ya kesi';

  @override
  String get welfareEditRule => 'Hariri aina ya kesi';

  @override
  String get welfareRuleName => 'Jina';

  @override
  String get welfareRuleNameHint => 'mfano Mwanachama amelazwa';

  @override
  String get welfareRuleDescription => 'Kifungu cha katiba / maelezo';

  @override
  String get welfareContributionPerMember => 'Mchango kwa kila mwanachama';

  @override
  String get welfareYearEnd => 'Mwisho wa mwaka';

  @override
  String get welfareYearEndHelp =>
      'Huhamisha salio la ustawi ambalo halijatumika kwenda Mfuko wa Ustawi.';

  @override
  String welfareCloseYear(int year) {
    return 'Funga $year';
  }

  @override
  String welfareCloseYearTitle(int year) {
    return 'Funga mwaka wa ustawi $year?';
  }

  @override
  String welfareCloseYearBody(int year) {
    return 'Salio la ustawi la $year ambalo halijatumika la kila mwanachama litahamia Mfuko wa Ustawi. Haliwezi kurudishwa.';
  }

  @override
  String welfareYearClosing(int year) {
    return 'Inafunga $year. Salio litasasishwa hivi punde.';
  }

  @override
  String welfareYearClosed(int year) {
    return '$year imefungwa.';
  }

  @override
  String get welfareFilterOpen => 'Wazi';

  @override
  String get welfareStatusPENDING_APPROVAL => 'Inasubiri idhini';

  @override
  String get welfareStatusAPPROVED => 'Imeidhinishwa';

  @override
  String get welfareStatusREJECTED => 'Imekataliwa';

  @override
  String get welfareStatusCLOSED => 'Imefungwa';

  @override
  String get welfareNewCase => 'Kesi mpya';

  @override
  String get welfareNoCases => 'Hakuna kesi hapa.';

  @override
  String welfareCollectedOf(String collected, String total) {
    return 'Imekusanywa $collected kati ya $total';
  }

  @override
  String get welfarePickMember => 'Chagua mwanachama';

  @override
  String get welfareCaseType => 'Aina ya kesi';

  @override
  String welfareLevyPreview(String amount) {
    return 'Ikiidhinishwa, kila mwanachama hai atachangia $amount, kuanzia kwenye salio lake la ustawi.';
  }

  @override
  String get welfareAffectedPerson => 'Mhusika';

  @override
  String get welfareAffectedPersonHint =>
      'Kama si mwanachama, mfano Mary W. (binti)';

  @override
  String get welfareCaseDetails => 'Maelezo';

  @override
  String get welfareNeedsApproval =>
      'Mtu wa pili (mfano mweka hazina) lazima aidhinishe kabla wanachama hawajatozwa.';

  @override
  String get welfareOpenCase => 'Fungua kesi';

  @override
  String get welfareCaseOpened => 'Kesi imefunguliwa, inasubiri idhini';

  @override
  String get welfareCase => 'Kesi ya ustawi';

  @override
  String get welfareBeneficiary => 'Mwanachama';

  @override
  String get welfareOpenedBy => 'Imefunguliwa na';

  @override
  String get welfareDecidedBy => 'Imeamuliwa na';

  @override
  String get welfareCollection => 'Makusanyo';

  @override
  String get welfareLevyRunning => 'Inawatoza wanachama…';

  @override
  String get welfareMembersLevied => 'Wanachama waliotozwa';

  @override
  String get welfareTotalLevied => 'Jumla iliyotozwa';

  @override
  String get welfareCollected => 'Imekusanywa';

  @override
  String get welfareOutstanding => 'Bado inadaiwa kwa wanachama';

  @override
  String get welfarePaidOut => 'Imelipwa';

  @override
  String get welfareAvailable => 'Inapatikana kulipwa';

  @override
  String get welfareApproveTitle => 'Idhinisha kesi';

  @override
  String get welfareRejectTitle => 'Kataa kesi';

  @override
  String get welfareReason => 'Sababu';

  @override
  String get welfareNotesOptional => 'Maelezo (hiari)';

  @override
  String get welfareApproved => 'Imeidhinishwa. Wanachama wanatozwa.';

  @override
  String get welfareRejected => 'Kesi imekataliwa';

  @override
  String get welfareApproveHelp =>
      'Kuidhinisha huwatoza wanachama wote hai. Huwezi kuidhinisha kesi uliyoifungua.';

  @override
  String get welfareRecordPayout => 'Rekodi malipo';

  @override
  String welfarePayoutHelp(String amount) {
    return 'Rekodi pesa zilizokwisha kukabidhiwa mwanachama. Hadi $amount inapatikana.';
  }

  @override
  String welfareMoreThanAvailable(String amount) {
    return 'Ni $amount tu inayopatikana';
  }

  @override
  String get welfarePaidTo => 'Amelipwa';

  @override
  String get welfareReference => 'Kumbukumbu / nambari ya risiti';

  @override
  String get welfarePaidOn => 'Tarehe ya malipo';

  @override
  String get welfarePayoutRecorded => 'Malipo yamerekodiwa';

  @override
  String get welfareCloseCase => 'Funga kesi';

  @override
  String get welfareCaseClosed => 'Kesi imefungwa';

  @override
  String get welfarePayouts => 'Malipo';

  @override
  String get welfareWhoOwes => 'Michango ya wanachama';

  @override
  String get welfareOnlyOwing => 'Wanaodaiwa tu';

  @override
  String get welfareEveryonePaid => 'Kila mtu amelipa.';

  @override
  String get welfareCounterHelp =>
      'Chagua mwanachama kuona hali yake ya ustawi na kurekodi malipo ya taslimu au benki.';

  @override
  String get welfareRecordPayment => 'Rekodi malipo';

  @override
  String get welfareAllocationHelp =>
      'Hulipa kwanza madeni ya zamani zaidi; kinachobaki huenda kwenye salio la mwaka.';

  @override
  String get welfarePaymentRecorded => 'Malipo yamerekodiwa';

  @override
  String get navLeader => 'Uongozi';

  @override
  String get leaderTitle => 'Uongozi';

  @override
  String get leaderNeedsAttention => 'Yanayohitaji hatua yako';

  @override
  String get leaderAllClear => 'Hakuna kinachokusubiri kwa sasa.';

  @override
  String get leaderModules => 'Zana zako';

  @override
  String get leaderFinance => 'Fedha';

  @override
  String get leaderFinanceHelp => 'Hali ya kifedha, jarida, orodha ya akaunti';

  @override
  String get leaderReports => 'Ripoti';

  @override
  String get leaderReportsHelp => 'Taarifa za fedha na ripoti za ukaguzi';

  @override
  String get leaderLoanDesk => 'Dawati la mikopo';

  @override
  String get leaderLoanDeskHelp => 'Tathmini, idhinisha, toa, rekodi marejesho';

  @override
  String get leaderMembers => 'Wanachama';

  @override
  String get leaderMembersHelp => 'Tafuta mwanachama, amana na utoaji kaunta';

  @override
  String get leaderMember => 'Mwanachama';

  @override
  String get leaderDistributions => 'Mgawanyo wa gawio na riba';

  @override
  String get leaderDistributionsHelp => 'Pendekeza, idhinisha na lipa';

  @override
  String get leaderWelfare => 'Usimamizi wa ustawi';

  @override
  String get leaderWelfareHelp =>
      'Kesi, malipo ya kaunta, kanuni, mwisho wa mwaka';

  @override
  String get taskLoansToAppraise => 'Mikopo inayosubiri tathmini';

  @override
  String get taskLoansToDecide => 'Mikopo inayosubiri uamuzi';

  @override
  String get taskLoansToDisburse => 'Mikopo iliyoidhinishwa ya kutolewa';

  @override
  String get taskDistributionsToApprove =>
      'Mgawanyo wa gawio / riba wa kuidhinisha';

  @override
  String get taskWelfareToApprove => 'Kesi za ustawi za kuidhinisha';

  @override
  String get financeBalanced => 'Vitabu vimesawazika';

  @override
  String get financeUnbalanced => 'Vitabu havijasawazika';

  @override
  String get financeTrialBalanceHint => 'Gusa kufungua mizania ya majaribio';

  @override
  String get financeCash => 'Taslimu na benki';

  @override
  String get financeCollectionsToday => 'Pesa kwa simu leo';

  @override
  String get financeLoans => 'Mikopo inayodaiwa';

  @override
  String get financePar => 'Mikopo hatarini (>siku 30)';

  @override
  String get financeWelfareFund => 'Mfuko wa ustawi';

  @override
  String get financeMembers => 'Wanachama hai';

  @override
  String get financeThisYear => 'Mwaka huu';

  @override
  String get financeIncome => 'Mapato';

  @override
  String get financeExpenses => 'Matumizi';

  @override
  String get financeSurplus => 'Ziada / (upungufu)';

  @override
  String get financeTools => 'Zana';

  @override
  String get financeJournal => 'Jarida';

  @override
  String get financeJournalHelp =>
      'Kila kumbukumbu; rekebisha makosa kwa kurudisha';

  @override
  String get financeNewEntry => 'Kumbukumbu mpya ya jarida';

  @override
  String get financeNewEntryHelp => 'Matumizi, ada, gharama za benki';

  @override
  String get financeChart => 'Orodha ya akaunti';

  @override
  String get financeChartHelp => 'Akaunti na kuongeza mpya';

  @override
  String journalReversedBy(String ref) {
    return 'imerudishwa na $ref';
  }

  @override
  String journalReverses(String ref) {
    return 'inarudisha $ref';
  }

  @override
  String get journalDate => 'Tarehe';

  @override
  String get journalPostedBy => 'Imewekwa na';

  @override
  String get journalReversesLabel => 'Inarudisha';

  @override
  String get journalReversedByLabel => 'Imerudishwa na';

  @override
  String get journalLines => 'Mistari';

  @override
  String get debitShort => 'Dr';

  @override
  String get creditShort => 'Cr';

  @override
  String get debit => 'Debiti';

  @override
  String get credit => 'Krediti';

  @override
  String get journalReverse => 'Rudisha kumbukumbu hii';

  @override
  String get journalReverseTitle => 'Rudisha kumbukumbu';

  @override
  String get journalReverseHelp =>
      'Kumbukumbu hazihaririwi wala kufutwa. Hii huweka kumbukumbu sawa na kinyume, zote zikibaki kwenye rekodi.';

  @override
  String get journalReversed => 'Kumbukumbu imerudishwa';

  @override
  String get journalDescription => 'Maelezo';

  @override
  String get journalControlHelp =>
      'Akaunti za wanachama (akiba, hisa, mikopo, ustawi) hazionyeshwi; hubadilika kupitia skrini zake tu.';

  @override
  String get journalAccount => 'Akaunti';

  @override
  String get journalMemo => 'Maelezo ya mstari (hiari)';

  @override
  String get journalAddLine => 'Ongeza mstari';

  @override
  String get journalDifference => 'Tofauti';

  @override
  String get journalPost => 'Weka kumbukumbu';

  @override
  String get journalPosted => 'Kumbukumbu imewekwa';

  @override
  String get journalNeedsDescription => 'Ongeza maelezo.';

  @override
  String get journalNeedsTwoLines =>
      'Kumbukumbu inahitaji angalau mistari miwili yenye akaunti na kiasi.';

  @override
  String get journalOneSidePerLine =>
      'Kila mstari ni debiti au krediti, si vyote.';

  @override
  String get journalNotBalanced => 'Debiti na krediti lazima zilingane.';

  @override
  String get chartAdd => 'Ongeza akaunti';

  @override
  String get chartCode => 'Msimbo';

  @override
  String get chartName => 'Jina';

  @override
  String get chartNameHint => 'mfano Kodi ya ofisi';

  @override
  String get chartType => 'Aina';

  @override
  String get chartAdded => 'Akaunti imeongezwa';

  @override
  String get chartControl => 'Akaunti kuu ya wanachama';

  @override
  String get typeAsset => 'Mali';

  @override
  String get typeLiability => 'Madeni';

  @override
  String get typeEquity => 'Mtaji';

  @override
  String get typeIncome => 'Mapato';

  @override
  String get typeExpense => 'Matumizi';

  @override
  String get reportsIntro =>
      'Takwimu zinatoka moja kwa moja kwenye daftari. Shiriki ripoti yoyote kama jedwali (CSV) kwa ukaguzi wa ndani, wa nje au wa Mkaguzi Mkuu.';

  @override
  String get reportsNone => 'Hakuna ripoti kwa jukumu lako.';

  @override
  String get reportTrialBalance => 'Mizania ya majaribio';

  @override
  String get reportTrialBalanceHelp =>
      'Salio la debiti au krediti la kila akaunti';

  @override
  String get reportBalanceSheet => 'Taarifa ya hali ya kifedha';

  @override
  String get reportBalanceSheetHelp => 'Mali, madeni na mtaji';

  @override
  String get reportIncomeStatement => 'Taarifa ya mapato na matumizi';

  @override
  String get reportIncomeStatementHelp =>
      'Mapato, matumizi na ziada kwa kipindi';

  @override
  String get reportGeneralLedger => 'Daftari kuu';

  @override
  String get reportGeneralLedgerHelp => 'Miamala ya akaunti moja na salio';

  @override
  String get reportJournal => 'Jarida (kitabu cha siku)';

  @override
  String get reportJournalHelp => 'Kila kumbukumbu, aliyeweka, marudisho';

  @override
  String get reportMemberBalances => 'Salio za wanachama na upatanisho';

  @override
  String get reportMemberBalancesHelp =>
      'Salio za kila mwanachama, zikilinganishwa na akaunti kuu';

  @override
  String get reportLoanPortfolio => 'Mikopo na malimbikizo';

  @override
  String get reportLoanPortfolioHelp =>
      'Mikopo inayodaiwa, umri wa madeni na hatari';

  @override
  String get reportCollections => 'Makusanyo ya pesa kwa simu';

  @override
  String get reportCollectionsHelp => 'Malipo ya M-Pesa / Selcom kwa matokeo';

  @override
  String get reportDistributions => 'Rejista ya gawio na riba';

  @override
  String get reportDistributionsHelp =>
      'Kiasi kilichotangazwa pamoja na kodi ya zuio';

  @override
  String get reportExport => 'Shiriki kama jedwali';

  @override
  String get reportAsAt => 'Hadi tarehe';

  @override
  String get reportFrom => 'Kuanzia';

  @override
  String get reportTo => 'Hadi';

  @override
  String reportGeneratedBy(String name, String currency) {
    return 'Imeandaliwa na $name · kiasi kwa $currency';
  }

  @override
  String get reportNoRows => 'Hakuna kitu katika kipindi hiki.';

  @override
  String get runPropose => 'Pendekeza mgawanyo';

  @override
  String get noRuns => 'Hakuna mgawanyo bado.';

  @override
  String runMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'wanachama $count',
      one: 'mwanachama 1',
    );
    return '$_temp0';
  }

  @override
  String get runPeriod => 'Kipindi';

  @override
  String get runRate => 'Kiwango';

  @override
  String get runMembersLabel => 'Wanachama';

  @override
  String get runProposedBy => 'Imependekezwa na';

  @override
  String get runWhtUnconfirmed =>
      'Viwango vya kodi ya zuio bado havijathibitishwa na mshauri wa kodi.';

  @override
  String get runApproveTitle => 'Idhinisha mgawanyo?';

  @override
  String runApproveBody(String amount) {
    return 'Hii itaweka $amount halisi kwenye akaunti za wanachama katika daftari.';
  }

  @override
  String get runApproveHelp => 'Huwezi kuidhinisha mgawanyo uliopendekeza.';

  @override
  String get runApproved => 'Mgawanyo umeidhinishwa na kuwekwa';

  @override
  String get runRejectTitle => 'Kataa mgawanyo';

  @override
  String get runRejected => 'Mgawanyo umekataliwa';

  @override
  String get runPayout => 'Lipa kwa pesa kwa simu';

  @override
  String runPayoutBody(String amount) {
    return 'Tuma $amount kwa simu za wanachama sasa?';
  }

  @override
  String get runPayoutStarted => 'Malipo yameanza';

  @override
  String get runRatePercent => 'Kiwango (%)';

  @override
  String get runRatePercentOptional =>
      'Kiwango (%) - wazi hutumia kiwango cha bidhaa';

  @override
  String get runDescription => 'Maelezo, mfano Gawio la AGM FY2025';

  @override
  String get runProposeHelp =>
      'Kiongozi mwingine lazima aidhinishe kabla chochote hakijawekwa.';

  @override
  String get runRateRequired => 'Weka kiwango cha gawio.';

  @override
  String get runProposed => 'Mgawanyo umependekezwa, unasubiri idhini';

  @override
  String get welfareRequiredProduct => 'Chagua bidhaa ya akiba.';

  @override
  String get queueAppraise => 'Za kutathmini';

  @override
  String get queueDecide => 'Za kuamua';

  @override
  String get queueDisburse => 'Za kutoa';

  @override
  String get queueActive => 'Zinazoendelea';

  @override
  String get queueEmpty => 'Hakuna mikopo hapa.';

  @override
  String queueDaysOverdue(int days) {
    return 'Imechelewa siku $days';
  }

  @override
  String get queueArrears => 'Malimbikizo';

  @override
  String get queueAppraisedBy => 'Imetathminiwa na';

  @override
  String get queueAppraisalNotes => 'Maelezo ya tathmini';

  @override
  String queuePledged(String amount) {
    return 'Jumla ya dhamana: $amount';
  }

  @override
  String get queueAppraiseAction => 'Rekodi tathmini';

  @override
  String get queueAppraised => 'Tathmini imerekodiwa';

  @override
  String get queueApproved => 'Mkopo umeidhinishwa';

  @override
  String get queueRejected => 'Mkopo umekataliwa';

  @override
  String get queueDisburseAction => 'Toa mkopo';

  @override
  String get queueToSavings => 'Kwenye akiba';

  @override
  String get queueDisbursed => 'Utoaji umetumwa';

  @override
  String get queueAwaitingProvider =>
      'Inasubiri mtoa huduma wa pesa kwa simu kuthibitisha.';

  @override
  String get queueRecordRepayment => 'Rekodi marejesho';

  @override
  String get queueRepaymentRecorded => 'Marejesho yamerekodiwa';

  @override
  String get counterActions => 'Kaunta';

  @override
  String get counterWithdraw => 'Toa akiba';

  @override
  String counterWithdrawConfirm(String amount, String name) {
    return 'Mlipe $name $amount?';
  }

  @override
  String get counterFromAccount => 'Kutoka akaunti';

  @override
  String get counterRecorded => 'Imerekodiwa';

  @override
  String get counterVerifyKyc => 'Thibitisha KYC';

  @override
  String get counterVerifyKycBody =>
      'Thibitisha umekagua vitambulisho vya mwanachama huyu.';

  @override
  String get counterPledged => 'Imefungwa kama dhamana';

  @override
  String get counterLimitedView =>
      'Jukumu lako linaonyesha taarifa za mwanachama tu.';

  @override
  String get brandTagline => 'Kikundi cha Uwezeshaji';

  @override
  String get connecting => 'Inaunganisha…';

  @override
  String get navFinance => 'Fedha';

  @override
  String get navLoanDesk => 'Mikopo';

  @override
  String get navMembers => 'Wanachama';

  @override
  String get navReports => 'Ripoti';

  @override
  String get navDividends => 'Gawio';

  @override
  String get navMore => 'Zaidi';

  @override
  String get moreProfileHelp => 'Picha, nenosiri, lugha';

  @override
  String get photoTake => 'Piga picha';

  @override
  String get photoChoose => 'Chagua kutoka picha';

  @override
  String get photoPickFailed =>
      'Imeshindikana kufungua picha hiyo. Jaribu nyingine.';

  @override
  String get photoUploading => 'Inapakia picha…';

  @override
  String get photoUpdated => 'Picha ya wasifu imesasishwa';

  @override
  String get yes => 'Ndiyo';

  @override
  String get no => 'Hapana';

  @override
  String get submit => 'Wasilisha';

  @override
  String get upload => 'Pakia';

  @override
  String get uploaded => 'Imepakiwa';

  @override
  String get replace => 'Badilisha';

  @override
  String get field => 'Taarifa';

  @override
  String get now => 'Sasa';

  @override
  String get newValue => 'Badilisha kuwa';

  @override
  String get onRecord => 'Taarifa';

  @override
  String get myDetailsTitle => 'Taarifa zangu na familia';

  @override
  String get myDetailsHelp => 'Taarifa binafsi, kitambulisho, familia';

  @override
  String get personalDetails => 'Taarifa binafsi';

  @override
  String get basicDetails => 'Mawasiliano na kazi';

  @override
  String get basicDetailsHelp => 'Unaweza kubadilisha hizi wakati wowote.';

  @override
  String get idDocuments => 'Kitambulisho';

  @override
  String get idFront => 'Mbele ya kitambulisho';

  @override
  String get idBack => 'Nyuma ya kitambulisho';

  @override
  String get tapToScan => 'Gusa kupiga picha';

  @override
  String get idScanFrontTip =>
      'Weka kitambulisho sawa mahali penye mwanga, jaza fremu, epuka mng\'ao.';

  @override
  String get idScanBackTip => 'Sasa upande wa nyuma wa kitambulisho.';

  @override
  String get idNotRead =>
      'Hatukuweza kusoma nambari ya kitambulisho. Bado unaweza kuipakia; Katibu ataikagua.';

  @override
  String idReadMatches(String number) {
    return 'Nambari iliyosomwa $number. Inalingana na rekodi yako.';
  }

  @override
  String idReadDifferent(String read, String record) {
    return 'Nambari iliyosomwa $read, lakini rekodi yako inasema $record. Kagua picha, au omba kubadilisha nambari.';
  }

  @override
  String get idNumberMatches => 'Nambari inalingana';

  @override
  String get idNumberMismatch => 'Nambari haifanani';

  @override
  String idNumberRead(String number) {
    return 'Iliyosomwa: $number';
  }

  @override
  String get documentUploaded => 'Hati imepakiwa';

  @override
  String get documentOnFile => 'Hati imehifadhiwa';

  @override
  String get documentLoadFailed => 'Imeshindikana kupakua hati hii.';

  @override
  String get pdfOnFile => 'PDF hii imehifadhiwa; ifungue kwenye wavuti kuiona.';

  @override
  String get familyRegister => 'Rejista ya familia';

  @override
  String get familyRegisterHelp =>
      'Ni watu walioidhinishwa hapa tu wanaolindwa na ustawi.';

  @override
  String get familyEmpty => 'Hakuna wanafamilia waliosajiliwa bado.';

  @override
  String get addFamilyMember => 'Ongeza mwanafamilia';

  @override
  String get familyFormHelp =>
      'Katibu humwidhinisha kila mtu kabla ya kulindwa na ustawi. Ongeza cheti cha kuzaliwa au kitambulisho baadaye.';

  @override
  String get fieldFirstName => 'Jina la kwanza';

  @override
  String get fieldLastName => 'Jina la ukoo';

  @override
  String get fieldOtherNames => 'Majina mengine';

  @override
  String get fieldFullName => 'Jina kamili';

  @override
  String get fieldDateOfBirth => 'Tarehe ya kuzaliwa';

  @override
  String get fieldGender => 'Jinsia';

  @override
  String get fieldIdType => 'Aina ya kitambulisho';

  @override
  String get fieldMaritalStatus => 'Hali ya ndoa';

  @override
  String get fieldRelationship => 'Uhusiano';

  @override
  String get fieldBirthCert => 'Nambari ya cheti cha kuzaliwa';

  @override
  String get fieldNextOfKin => 'Mrithi / ndugu wa karibu';

  @override
  String get fieldDeceased => 'Marehemu';

  @override
  String get fieldOccupation => 'Kazi';

  @override
  String get fieldEmployer => 'Mwajiri';

  @override
  String get fieldCounty => 'Kaunti / mkoa';

  @override
  String get relSpouse => 'Mwenzi';

  @override
  String get relChild => 'Mtoto';

  @override
  String get relParent => 'Mzazi';

  @override
  String get relParentInLaw => 'Mkwe';

  @override
  String get relSibling => 'Ndugu';

  @override
  String get relSelf => 'Mwanachama mwenyewe';

  @override
  String get genderFemale => 'Mke';

  @override
  String get genderMale => 'Mume';

  @override
  String get genderOther => 'Nyingine';

  @override
  String get maritalSingle => 'Hajaoa / hajaolewa';

  @override
  String get maritalMarried => 'Ameoa / ameolewa';

  @override
  String get maritalWidowed => 'Mjane';

  @override
  String get maritalDivorced => 'Ametalikiana';

  @override
  String get idTypeNational => 'Kitambulisho cha taifa';

  @override
  String get idTypeHuduma => 'Huduma Namba';

  @override
  String get idTypeNida => 'NIDA';

  @override
  String get idTypePassport => 'Pasipoti';

  @override
  String ageYears(int age) {
    return 'miaka $age';
  }

  @override
  String get statusApproved => 'Imeidhinishwa';

  @override
  String get statusAwaitingApproval => 'Inasubiri idhini';

  @override
  String get statusRejected => 'Imekataliwa';

  @override
  String get requestChange => 'Omba mabadiliko';

  @override
  String get requestRemoval => 'Omba kuondolewa';

  @override
  String get cancelRequest => 'Ghairi ombi';

  @override
  String get requestCancelled => 'Ombi limeghairiwa';

  @override
  String get changeAwaitingApproval => 'Mabadiliko yanasubiri idhini';

  @override
  String get changeSentForApproval => 'Imetumwa kwa Katibu kuidhinishwa';

  @override
  String get sendForApproval => 'Tuma kwa idhini';

  @override
  String get changeReason => 'Sababu ya mabadiliko (husaidia idhini)';

  @override
  String get nothingChanged => 'Hakuna kilichobadilika.';

  @override
  String get personalChangeHelp =>
      'Mabadiliko ya taarifa hizi hukaguliwa na kuidhinishwa na Katibu kabla ya kutumika. Pakia kitambulisho ikiwa nambari au majina yanabadilika.';

  @override
  String get childDobRequired =>
      'Tarehe ya kuzaliwa ya mtoto inahitajika kwa ulinzi wa ustawi.';

  @override
  String get uploadBirthCert => 'Pakia cheti cha kuzaliwa';

  @override
  String get uploadIdPhoto => 'Pakia picha ya kitambulisho';

  @override
  String removalHelp(String name) {
    return 'Kumwondoa $name kunamaanisha ustawi hautamlinda tena. Katibu lazima aidhinishe.';
  }

  @override
  String get myRequests => 'Maombi yangu';

  @override
  String get submitForApproval => 'Wasilisha kwa idhini';

  @override
  String get submitForApprovalTitle => 'Wasilisha taarifa zako?';

  @override
  String get submitForApprovalBody =>
      'Katibu atakagua taarifa zako na kitambulisho. Zikiidhinishwa, mabadiliko yatahitaji idhini.';

  @override
  String get submittedForApproval => 'Imewasilishwa kwa idhini';

  @override
  String get profileDraft => 'Kamilisha wasifu wako';

  @override
  String get profileDraftHelp =>
      'Kagua taarifa zako, piga picha ya kitambulisho na ongeza familia, kisha wasilisha.';

  @override
  String get profilePending => 'Inasubiri idhini';

  @override
  String get profilePendingHelp => 'Katibu anakagua taarifa zako.';

  @override
  String get profileVerified => 'Wasifu umethibitishwa';

  @override
  String get profileVerifiedHelp =>
      'Taarifa zako zimefungwa. Mabadiliko yanahitaji idhini ya Katibu.';

  @override
  String get profileActionNeeded => 'Hatua inahitajika';

  @override
  String get profileNotSubmitted => 'Haijawasilishwa';

  @override
  String get completeProfileTitle => 'Kamilisha wasifu wako';

  @override
  String get completeProfileBody =>
      'Ongeza kitambulisho na familia ili ustawi uwalinde.';

  @override
  String get navApprovals => 'Idhini';

  @override
  String get approvalsTitle => 'Idhini za wanachama';

  @override
  String get approvalsHelp => 'Mabadiliko ya wasifu, kitambulisho na familia';

  @override
  String get approvalsEmpty => 'Hakuna kinachosubiri idhini.';

  @override
  String get firstProfileApproval => 'Wasifu mpya wa kuthibitisha';

  @override
  String memberSays(String note) {
    return 'Maelezo ya mwanachama: $note';
  }

  @override
  String get whatChanges => 'Kinachobadilika';

  @override
  String get documentsToCheck => 'Hati za kukagua';

  @override
  String get noDocumentsYet => 'Hakuna hati zilizopakiwa bado.';

  @override
  String get compareIdHelp =>
      'Linganisha picha ya kitambulisho na taarifa kabla ya kuidhinisha. Ukaguzi wa nambari ni mwongozo tu.';

  @override
  String get removalWarning =>
      'Kuidhinisha kutamwondoa mtu huyu kwenye ulinzi wa ustawi.';

  @override
  String get rejectReasonForMember => 'Sababu (mwanachama ataiona)';

  @override
  String get changeApproved => 'Imeidhinishwa';

  @override
  String get changeRejected => 'Imekataliwa';

  @override
  String get tableMember => 'Mwanachama';

  @override
  String get tableStatus => 'Hali';

  @override
  String get tableProfile => 'Wasifu';

  @override
  String tableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'wanachama $count',
      one: 'mwanachama 1',
    );
    return '$_temp0';
  }

  @override
  String get memberDormant => 'Hasiti';

  @override
  String get memberExited => 'Ameondoka';

  @override
  String get welfareCovers => 'Inawalinda nani';

  @override
  String get welfareCoversRequired =>
      'Chagua angalau mtu mmoja aina hii inamlinda.';

  @override
  String get welfareChildMaxAge => 'Kikomo cha umri wa mtoto (hiari)';

  @override
  String get welfareChildMaxAgeHint => 'mfano 18';

  @override
  String get welfarePickAffected => 'Chagua kesi ni ya nani.';

  @override
  String get welfareNobodyCovered =>
      'Hakuna kwenye rejista ya mwanachama huyu anayelindwa na aina hii.';

  @override
  String get welfareNobodyCoveredHelp =>
      'Mwanachama lazima amwongeze mtu huyo kwenye rejista na aidhinishwe kwanza.';

  @override
  String get welfareRegisterOnlyHelp =>
      'Ni walioidhinishwa kwenye rejista tu wanaolindwa.';

  @override
  String get navMeetings => 'Mikutano';

  @override
  String get navActivity => 'Wasiofanya';

  @override
  String get meetingsTitle => 'Mikutano';

  @override
  String get meetingsHelp => 'Panga mikutano na chukua mahudhurio';

  @override
  String get myMeetingsHelp => 'Mikutano ijayo, udhuru, mahudhurio yangu';

  @override
  String get meetingsUpcoming => 'Ijayo';

  @override
  String get meetingsPast => 'Iliyopita';

  @override
  String get meetingsNoneUpcoming => 'Hakuna mikutano ijayo.';

  @override
  String get meetingsNonePast => 'Hakuna mikutano iliyopita bado.';

  @override
  String get meetingSchedule => 'Panga mkutano';

  @override
  String get meetingType => 'Aina ya mkutano';

  @override
  String get meetingAgm => 'Mkutano mkuu wa mwaka';

  @override
  String get meetingSgm => 'Mkutano mkuu maalum';

  @override
  String get meetingMonthly => 'Mkutano wa kila mwezi';

  @override
  String get meetingCommittee => 'Mkutano wa kamati';

  @override
  String get meetingBoard => 'Mkutano wa bodi';

  @override
  String get meetingTitleLabel => 'Kichwa';

  @override
  String get meetingTitleHint => 'mfano Mkutano wa Oktoba';

  @override
  String get meetingTime => 'Saa';

  @override
  String get meetingVenue => 'Mahali';

  @override
  String get meetingAgenda => 'Ajenda';

  @override
  String get meetingSendNotice => 'Tuma ujumbe kwa wanachama wote';

  @override
  String get meetingSendNoticeHelp =>
      'Wanachama wanaweza kutuma udhuru kwenye programu.';

  @override
  String get meetingNotCounted =>
      'Mikutano ya kamati na bodi haihesabiwi kwenye kanuni ya mahudhurio.';

  @override
  String get meetingScheduled => 'Mkutano umepangwa';

  @override
  String get meetingScheduledNotified =>
      'Mkutano umepangwa na wanachama wamearifiwa';

  @override
  String get meetingCancel => 'Ghairi mkutano';

  @override
  String get meetingCancelBody =>
      'Ghairi mkutano huu? Hautahesabiwa kwa mahudhurio.';

  @override
  String get meetingCancelled => 'Umeghairiwa';

  @override
  String meetingApologiesIn(int count) {
    return 'udhuru $count';
  }

  @override
  String get attPresent => 'Alihudhuria';

  @override
  String get attLate => 'Alichelewa';

  @override
  String get attApology => 'Udhuru';

  @override
  String get attAbsent => 'Hakuhudhuria';

  @override
  String get attNotMarked => 'Haijawekwa';

  @override
  String get registerSaved => 'Mahudhurio yamehifadhiwa';

  @override
  String get registerClose => 'Funga mahudhurio';

  @override
  String registerCloseBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Wanachama $count hawajawekwa na wataandikwa hawakuhudhuria bila udhuru.',
      one: 'Mwanachama 1 hajawekwa na ataandikwa hakuhudhuria bila udhuru.',
      zero: 'Wote wamewekwa. Funga mahudhurio?',
    );
    return '$_temp0';
  }

  @override
  String get registerClosed => 'Mahudhurio yamefungwa';

  @override
  String get registerHeldHelp =>
      'Mahudhurio haya yamefungwa. Bado unaweza kusahihisha.';

  @override
  String apologyReasonShown(String reason) {
    return 'Udhuru: $reason';
  }

  @override
  String get sendApology => 'Tuma udhuru';

  @override
  String get apologyReason => 'Sababu';

  @override
  String get apologyHelp =>
      'Udhuru unamaanisha kutokuwepo huku hakutahesabiwa dhidi yako.';

  @override
  String get apologySent => 'Udhuru umetumwa';

  @override
  String get myAttendance => 'Mahudhurio yangu';

  @override
  String missedMeetingsStreak(int count, int limit) {
    return 'Mikutano $count mfululizo bila udhuru (kikomo $limit)';
  }

  @override
  String get missedMeetingsHelp =>
      'Hudhuria mkutano ujao au tuma udhuru ili ubaki hai.';

  @override
  String get atRiskTitle => 'Uanachama wako unaweza kusitishwa';

  @override
  String atRiskMonths(int count) {
    return 'Miezi $count bila mchango wa kila mwezi';
  }

  @override
  String atRiskMeetings(int count) {
    return 'Mikutano $count bila udhuru';
  }

  @override
  String get dormantTitle => 'Uanachama wako umesitishwa';

  @override
  String get dormantBody =>
      'Unaweza kuona na kulipa, lakini si kukopa wala kudhamini, na ustawi haukulindi. Toa mchango wa mwezi au hudhuria mkutano ili urejeshwe.';

  @override
  String get taskProfileChanges => 'Mabadiliko ya wasifu ya kuidhinisha';

  @override
  String get taskMembersToArchive => 'Wanachama wasiofanya kazi wa kukagua';

  @override
  String get activityTitle => 'Wanachama wasiofanya kazi';

  @override
  String get activityHelp => 'Sitisha au rejesha wanachama; kanuni';

  @override
  String get activityFlagged => 'Wa kukagua';

  @override
  String get activityDormant => 'Waliositishwa';

  @override
  String get activityRules => 'Kanuni';

  @override
  String get activityFlaggedHelp =>
      'Wanachama waliovuka kikomo katika ukaguzi wa mwezi. Walionywa kwa SMS hatua moja kabla.';

  @override
  String get activityNoneFlagged => 'Hakuna wa kukagua.';

  @override
  String get activityKeepActive => 'Mbakize hai';

  @override
  String get activityKeepActiveHelp => 'Mfano amekubali mpango wa malipo.';

  @override
  String get activityKept => 'Amebakizwa hai';

  @override
  String get activityArchive => 'Sitisha';

  @override
  String activityArchiveBody(String name) {
    return '$name atasitishwa: anaweza kuona na kulipa, lakini si kukopa wala kudhamini, na hatatozwa wala kulindwa na ustawi. Atarejeshwa moja kwa moja akichangia au kuhudhuria.';
  }

  @override
  String get activityArchived => 'Mwanachama amesitishwa';

  @override
  String get activityDormantHelp =>
      'Hurejeshwa moja kwa moja wakichangia akiba ya mwezi au kuhudhuria mkutano.';

  @override
  String get activityNoneDormant => 'Hakuna waliositishwa.';

  @override
  String get activityReactivate => 'Rejesha';

  @override
  String get activityReactivated => 'Mwanachama amerejeshwa';

  @override
  String get activityRunNow => 'Fanya ukaguzi sasa';

  @override
  String activityCheckDone(int flagged, int warned) {
    return 'Ukaguzi umekamilika: $flagged wamewekwa alama, $warned wameonywa';
  }

  @override
  String activityLastRun(String date) {
    return 'Mara ya mwisho: $date';
  }

  @override
  String get activityNeverRun => 'Bado haujafanywa.';

  @override
  String get activityScheduleHelp =>
      'Pia hufanyika moja kwa moja tarehe 1 kila mwezi.';

  @override
  String get activityWarnBeforeLimit => 'Onyo lazima liwe kabla ya kikomo.';

  @override
  String get ruleContributions => 'Michango ya mwezi iliyokosekana';

  @override
  String get ruleContributionsHelp =>
      'Miezi mfululizo bila amana kwenye akiba ya lazima ya kila mwezi.';

  @override
  String get ruleWarnAfterMonths => 'Onyo la SMS baada ya (miezi)';

  @override
  String get ruleArchiveAfterMonths => 'Kagua kusitisha baada ya (miezi)';

  @override
  String get ruleMinAmount => 'Kiasi cha chini kwa mwezi';

  @override
  String get ruleMinAmountHelp => '0 = kiasi chochote kinahesabiwa.';

  @override
  String get ruleMeetings => 'Mikutano iliyokosekana';

  @override
  String get ruleMeetingsHelp => 'Mikutano mikuu mfululizo bila udhuru.';

  @override
  String get ruleWarnAfterMeetings => 'Onyo la SMS baada ya (mikutano)';

  @override
  String get ruleArchiveAfterMeetings => 'Kagua kusitisha baada ya (mikutano)';

  @override
  String get navAdmin => 'Utawala';

  @override
  String get adminTitle => 'Utawala na msaada';

  @override
  String get adminHelp => 'Watumiaji, nywila, nyadhifa, kumbukumbu';

  @override
  String get adminUsers => 'Watumiaji na msaada';

  @override
  String get adminUsersHelp =>
      'Tafuta mtu, weka upya nywila, zima au washa kuingia';

  @override
  String get adminPositions => 'Nyadhifa na majukumu';

  @override
  String get adminPositionsHelp => 'Wape watu nyadhifa, waondoe, unda mpya';

  @override
  String get adminAudit => 'Kumbukumbu za ukaguzi';

  @override
  String get adminAuditHelp =>
      'Nani alifanya au kuona nini, lini, wapi na kwa kifaa gani';

  @override
  String get adminSecurity => 'Kuingia na usalama';

  @override
  String get adminSecurityHelp =>
      'Kuingia, majaribio yaliyoshindwa, kuweka nywila upya, mabadiliko ya majukumu';

  @override
  String get allow => 'Ruhusu';

  @override
  String get notNow => 'Si sasa';

  @override
  String get anyDate => 'Tarehe yoyote';

  @override
  String get copy => 'Nakili';

  @override
  String get copied => 'Imenakiliwa';

  @override
  String get share => 'Shiriki';

  @override
  String get remove => 'Ondoa';

  @override
  String get notes => 'Maelezo';

  @override
  String get downloadCsv => 'Pakua CSV';

  @override
  String get idScan => 'Changanua kitambulisho';

  @override
  String idScanRead(String number) {
    return 'Nambari ya kitambulisho $number imesomwa';
  }

  @override
  String get paymentMethodLabel => 'Imelipwa kwa';

  @override
  String get receiptReference => 'Risiti / kumbukumbu';

  @override
  String get taskApplicationsToApprove => 'Wanachama wapya wa kuidhinisha';

  @override
  String get profileChangesTab => 'Mabadiliko ya wasifu';

  @override
  String get applicationsTitle => 'Wanachama wapya';

  @override
  String get applicationsEmpty => 'Hakuna maombi yanayosubiri.';

  @override
  String applicationBy(String name, String date) {
    return 'na $name, $date';
  }

  @override
  String applicationDecidedBy(String name, String date) {
    return 'Imeamuliwa na $name, $date';
  }

  @override
  String get applicationSubmitted => 'Imetumwa kuidhinishwa';

  @override
  String applicationApproved(String number) {
    return 'Imeidhinishwa - nambari $number';
  }

  @override
  String get applicationCancelled => 'Imeghairiwa';

  @override
  String get approveApplication => 'Idhinisha mwanachama mpya';

  @override
  String approveApplicationBody(String name) {
    return '$name atakuwa mwanachama wa majaribio na atapata kuingia kwa nywila ya muda.';
  }

  @override
  String get cancelApplication => 'Ghairi ombi';

  @override
  String get cancelApplicationBody =>
      'Ondoa ombi hili? Rudisha ada yoyote iliyokusanywa.';

  @override
  String get cantApproveOwnApplication =>
      'Ulimsajili mwombaji huyu, kwa hiyo mtu mwingine lazima aidhinishe.';

  @override
  String get registerMember => 'Sajili mwanachama';

  @override
  String get registerMemberHelp =>
      'Mwenyekiti (au mwidhinishaji mwingine) lazima aidhinishe kabla mwanachama hajaundwa. Nambari na kuingia hutolewa baada ya kuidhinishwa.';

  @override
  String get registrationFee => 'Ada ya usajili';

  @override
  String registrationFeeIs(String amount) {
    return 'Ada ya usajili ni $amount.';
  }

  @override
  String get registrationFeeZeroHelp => '0 = hakuna ada';

  @override
  String get feeCollectedNow => 'Ada imekusanywa sasa';

  @override
  String get feeCollectedHelp =>
      'Huandikwa vitabuni baada ya kuidhinishwa tu; irudishe likikataliwa.';

  @override
  String get feeNotCollected => 'Haikukusanywa wakati wa usajili.';

  @override
  String memberNumberIs(String number) {
    return 'Nambari ya mwanachama $number';
  }

  @override
  String get recordRegistrationFee => 'Rekodi ada ya usajili';

  @override
  String get registrationFeeRecorded => 'Ada ya usajili imerekodiwa';

  @override
  String get payRegistrationFee => 'Lipa ada ya usajili';

  @override
  String get payTitleRegistrationFee => 'Lipa ada ya usajili';

  @override
  String get registrationFeePayHelp =>
      'Mara moja na hairudishwi. Inahitajika kwa uanachama kamili.';

  @override
  String get membershipRules => 'Kanuni za uanachama';

  @override
  String membershipRulesSummary(String fee, int months) {
    return 'Ada $fee · kuthibitishwa baada ya michango $months ya mwezi mfululizo';
  }

  @override
  String get verificationMonthsLabel =>
      'Michango ya mwezi mfululizo ili kuthibitishwa';

  @override
  String get probation => 'Majaribio';

  @override
  String get probationTitle => 'Mwanachama mpya - majaribio';

  @override
  String get probationBody =>
      'Utakuwa mwanachama kamili haya yakikamilika. Hadi hapo huwezi kukopa, kudhamini, kulindwa na ustawi, kupiga kura au kushika wadhifa.';

  @override
  String probationFeePaid(String amount) {
    return 'Ada ya usajili $amount imelipwa';
  }

  @override
  String probationFeeDue(String amount) {
    return 'Ada ya usajili: $amount ya kulipa';
  }

  @override
  String probationMonths(int done, int total) {
    return 'Michango ya mwezi mfululizo: $done kati ya $total';
  }

  @override
  String get probationNoVote =>
      'Mwanachama mpya wa majaribio - hawezi kupiga kura bado';

  @override
  String get tempPasswordTitle => 'Chagua nywila yako';

  @override
  String get tempPasswordHelp =>
      'Umeingia kwa nywila ya muda. Chagua mpya unayoijua wewe tu.';

  @override
  String get tempPasswordCurrent => 'Nywila ya muda';

  @override
  String get tempPasswordIssued => 'Nywila ya muda';

  @override
  String get tempPasswordOnce =>
      'Inaonyeshwa sasa tu. Watachagua yao wakiingia.';

  @override
  String tempPasswordShareText(String name, String phone, String password) {
    return 'Inuka West: $name, ingia kwa simu yako $phone na nywila ya muda $password. Kisha utachagua yako.';
  }

  @override
  String get temporaryPasswordPending => 'Nywila ya muda';

  @override
  String get pickPerson => 'Chagua mtu';

  @override
  String get searchPeopleHint => 'Jina, simu au nambari';

  @override
  String get noPeopleFound => 'Hakuna aliyepatikana.';

  @override
  String get disabledLogins => 'Kuingia kulikozimwa';

  @override
  String get loginActive => 'Kuingia kunafanya kazi';

  @override
  String get loginDisabled => 'Kuingia kumezimwa';

  @override
  String get loginEnabled => 'Kuingia kumewashwa tena';

  @override
  String get disableLogin => 'Zima kuingia';

  @override
  String get enableLogin => 'Washa kuingia';

  @override
  String disableLoginBody(String name) {
    return '$name ataondolewa sasa na hataweza kuingia hadi kuwashwa. Kumbukumbu zake zinabaki.';
  }

  @override
  String enableLoginBody(String name) {
    return '$name ataweza kuingia tena.';
  }

  @override
  String get resetPassword => 'Weka upya nywila';

  @override
  String resetPasswordBody(String name) {
    return '$name atapata nywila ya muda ya kumpa, na ataondolewa kwenye kila simu.';
  }

  @override
  String get supportActions => 'Msaada';

  @override
  String get viewActivity => 'Angalia shughuli';

  @override
  String get lastSignIn => 'Kuingia mara ya mwisho';

  @override
  String get lastActive => 'Mara ya mwisho kutumia';

  @override
  String get neverSeen => 'Kamwe';

  @override
  String get seenJustNow => 'Sasa hivi';

  @override
  String seenMinutesAgo(int count) {
    return 'Dakika $count zilizopita';
  }

  @override
  String seenHoursAgo(int count) {
    return 'Saa $count zilizopita';
  }

  @override
  String seenDaysAgo(int count) {
    return 'Siku $count zilizopita';
  }

  @override
  String get devicesAndPlaces => 'Vifaa na mahali';

  @override
  String get recentActivity => 'Shughuli za karibuni';

  @override
  String get positionsHeld => 'Nyadhifa';

  @override
  String get givePosition => 'Mpe wadhifa';

  @override
  String givePositionTo(String name) {
    return 'Mpe $name wadhifa';
  }

  @override
  String get positionsHelp =>
      'Kila ofisi ina mshikaji na msaidizi, ili mmoja amkague mwingine. Wanachama wa majaribio hawawezi kushika wadhifa.';

  @override
  String get officesAndCommittees => 'Ofisi na kamati';

  @override
  String get staffRoles => 'Majukumu ya wafanyakazi';

  @override
  String holdersCount(int count) {
    return '$count wanashikilia';
  }

  @override
  String holdersOfMax(int count, int max) {
    return '$count kati ya $max';
  }

  @override
  String get positionFull => 'Imejaa';

  @override
  String get vacant => 'Wazi';

  @override
  String get assignPerson => 'Mweke mtu';

  @override
  String assistantTo(String name) {
    return 'Msaidizi wa $name';
  }

  @override
  String positionAssigned(String name, String position) {
    return '$name sasa ni $position';
  }

  @override
  String get positionRemoved => 'Ameondolewa kwenye wadhifa';

  @override
  String get removeFromPosition => 'Ondoa kwenye wadhifa';

  @override
  String removeFromPositionBody(String name, String position) {
    return 'Ondoa $name kwenye $position? Atapoteza ruhusa zake sasa.';
  }

  @override
  String get jobTitleOptional => 'Cheo (si lazima)';

  @override
  String get jobTitleHint => 'mfano Mweka hazina 2025-2027';

  @override
  String get newPosition => 'Wadhifa mpya';

  @override
  String get newPositionHelp =>
      'Mfano Katibu wa Nidhamu au Mwakilishi wa Vijana. Msaidizi hupata ruhusa sawa na ofisi anayoisaidia.';

  @override
  String get positionName => 'Jina';

  @override
  String get positionNameHint => 'mfano Mwakilishi wa Vijana';

  @override
  String get positionDuties => 'Majukumu';

  @override
  String get assistantOfLabel => 'Msaidizi wa';

  @override
  String get assistantOfHelp => 'Hufanya huu kuwa msaidizi wa ofisi.';

  @override
  String get notAnAssistant => 'Si msaidizi';

  @override
  String get copyPermissionsFrom => 'Ruhusa sawa na';

  @override
  String get copyPermissionsHelp => 'Anza na ruhusa za jukumu lililopo.';

  @override
  String get noPermissionsYet => 'Hakuna bado';

  @override
  String get maxHoldersLabel => 'Watu wangapi wanaweza kuushika';

  @override
  String get noLimit => 'Bila kikomo';

  @override
  String get createPosition => 'Unda wadhifa';

  @override
  String get positionCreated => 'Wadhifa umeundwa';

  @override
  String get auditSearchHint => 'Tafuta nani, nini, wapi, kifaa au IP';

  @override
  String get auditSecurityOnly => 'Kuingia na usalama tu';

  @override
  String get auditEmpty => 'Hakuna kilichorekodiwa kwa kichujio hiki.';

  @override
  String get auditWho => 'Nani';

  @override
  String get auditWhen => 'Lini';

  @override
  String get auditAction => 'Kitendo';

  @override
  String get auditRecord => 'Kumbukumbu';

  @override
  String get auditResult => 'Matokeo';

  @override
  String get auditOk => 'Imeruhusiwa';

  @override
  String auditRefused(int code) {
    return 'Imekataliwa ($code)';
  }

  @override
  String get auditWhere => 'Wapi';

  @override
  String get auditCoordinates => 'Viwianishi';

  @override
  String get auditIp => 'Anwani ya IP';

  @override
  String get auditDevice => 'Kifaa';

  @override
  String get auditRequest => 'Ombi';

  @override
  String get locationAskTitle => 'Linda akaunti yako';

  @override
  String get locationAskBody =>
      'Inuka West inaweza kurekodi eneo la takriban unapoingia, ili SACCO igundue mtu mwingine akitumia akaunti yako. Huhifadhiwa kwenye kumbukumbu za ukaguzi za SACCO tu. Unaweza kukataa.';

  @override
  String greetMorning(String name) {
    return 'Habari za asubuhi, $name';
  }

  @override
  String greetAfternoon(String name) {
    return 'Habari za mchana, $name';
  }

  @override
  String greetEvening(String name) {
    return 'Habari za jioni, $name';
  }

  @override
  String get greetMorningPlain => 'Habari za asubuhi';

  @override
  String get greetAfternoonPlain => 'Habari za mchana';

  @override
  String get greetEveningPlain => 'Habari za jioni';

  @override
  String get loginIdLabel => 'Simu au nambari ya mwanachama';

  @override
  String get loginIdHint => '0712 345 678 au IW-26-00123';
}
