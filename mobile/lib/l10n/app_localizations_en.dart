// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Inuka West';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get done => 'Done';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get networkError =>
      'Can\'t reach the server. Check your connection and try again.';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get findSaccoTitle => 'Find your SACCO';

  @override
  String get findSaccoBody =>
      'Enter the code your SACCO gave you. It\'s the first part of its web address, for example \"shirika\".';

  @override
  String get saccoCode => 'SACCO code';

  @override
  String get saccoNotFound => 'No SACCO found with that code.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get loginTitle => 'Log in';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get phoneHint => '+2547...';

  @override
  String get password => 'Password';

  @override
  String get loginSubmit => 'Log in';

  @override
  String get loginError => 'Login failed. Check your details and try again.';

  @override
  String get sessionExpired => 'Your session has expired. Please log in again.';

  @override
  String get noMemberRecord =>
      'This login has no member record and no staff tools available on mobile. Ask your SACCO administrator to assign you a role.';

  @override
  String get notYourSacco => 'Not your SACCO?';

  @override
  String get changeSacco => 'Change SACCO';

  @override
  String get unlockTitle => 'Unlock';

  @override
  String get unlockReason => 'Unlock your SACCO account';

  @override
  String get unlockButton => 'Unlock';

  @override
  String get usePassword => 'Log in with password instead';

  @override
  String get navHome => 'Home';

  @override
  String get navSavings => 'Savings';

  @override
  String get navLoans => 'Loans';

  @override
  String get navProfile => 'Profile';

  @override
  String welcome(String name) {
    return 'Welcome, $name';
  }

  @override
  String memberNumber(String number) {
    return 'Member no. $number';
  }

  @override
  String get shareCapital => 'Share capital';

  @override
  String get shareCapitalHelp =>
      'Your ownership stake. Earns dividends; not withdrawable.';

  @override
  String get savingsTotal => 'Savings';

  @override
  String get savingsHelp =>
      'Withdrawable deposits. Earn interest and set how much you can borrow.';

  @override
  String get loanOutstanding => 'Loan balance';

  @override
  String get noActiveLoans => 'No active loans';

  @override
  String nextPayment(String amount, String date) {
    return 'Next payment $amount due $date';
  }

  @override
  String overdue(int days, String amount) {
    return 'Overdue $days days · $amount';
  }

  @override
  String get quickActions => 'Quick actions';

  @override
  String get actionDeposit => 'Deposit';

  @override
  String get actionContribute => 'Buy shares';

  @override
  String get actionApply => 'Apply for loan';

  @override
  String get actionDividends => 'Dividends';

  @override
  String guaranteeRequestsBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members have asked you to guarantee their loans',
      one: '1 member has asked you to guarantee their loan',
    );
    return '$_temp0';
  }

  @override
  String get recentPayments => 'Recent mobile-money payments';

  @override
  String get savingsTitle => 'Savings & shares';

  @override
  String get savingsAccounts => 'Savings accounts';

  @override
  String get noSavingsAccounts =>
      'No savings accounts yet. Make a deposit to open one.';

  @override
  String get contributions => 'Contributions';

  @override
  String get transactions => 'Transactions';

  @override
  String get noTransactions => 'No transactions yet.';

  @override
  String get txDEPOSIT => 'Deposit';

  @override
  String get txWITHDRAWAL => 'Withdrawal';

  @override
  String get txCONTRIBUTION => 'Share contribution';

  @override
  String get withdrawalsAtBranch => 'Withdrawals are handled by your SACCO.';

  @override
  String pledgedLocked(String amount) {
    return '$amount locked as guarantee for other members\' loans';
  }

  @override
  String get payTitleDeposit => 'Deposit to savings';

  @override
  String get payTitleContribute => 'Buy shares';

  @override
  String get savingsProduct => 'Savings product';

  @override
  String get selectProduct => 'Select a product';

  @override
  String get amount => 'Amount';

  @override
  String get amountInvalid =>
      'Enter an amount greater than 0 with at most 2 decimals.';

  @override
  String get payFromPhone => 'Pay from phone number';

  @override
  String get mobileMoneyHelp =>
      'You\'ll get a mobile-money prompt on this phone to confirm.';

  @override
  String get payButton => 'Send payment request';

  @override
  String get payWaiting => 'Check your phone and enter your PIN to confirm…';

  @override
  String get paySuccess => 'Payment received';

  @override
  String get payFailed => 'Payment failed';

  @override
  String get payCancelled => 'Payment cancelled';

  @override
  String get payStillPending =>
      'Still waiting for confirmation. It will show in your statement once your provider confirms it.';

  @override
  String receipt(String receipt) {
    return 'Receipt $receipt';
  }

  @override
  String get statusPENDING => 'Pending';

  @override
  String get statusSUCCESS => 'Successful';

  @override
  String get statusFAILED => 'Failed';

  @override
  String get statusCANCELLED => 'Cancelled';

  @override
  String get purposeSAVINGS_DEPOSIT => 'Savings deposit';

  @override
  String get purposeSHARE_CONTRIBUTION => 'Share contribution';

  @override
  String get loansTitle => 'Loans';

  @override
  String get myLoans => 'My loans';

  @override
  String get noLoans => 'You haven\'t applied for a loan yet.';

  @override
  String get guaranteeRequests => 'Guarantee requests';

  @override
  String guaranteeFor(String name, String amount) {
    return '$name asks you to pledge $amount';
  }

  @override
  String get guaranteeWarning =>
      'Accepting locks this amount of your deposits until their loan is repaid. You won\'t be able to withdraw or borrow against it.';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get confirmAcceptTitle => 'Pledge your deposits?';

  @override
  String get loanStatusPENDING_GUARANTORS => 'Awaiting guarantors';

  @override
  String get loanStatusPENDING_APPRAISAL => 'Pending appraisal';

  @override
  String get loanStatusAPPRAISED => 'Appraised';

  @override
  String get loanStatusAPPROVED => 'Approved';

  @override
  String get loanStatusREJECTED => 'Rejected';

  @override
  String get loanStatusDISBURSED => 'Disbursement pending';

  @override
  String get loanStatusACTIVE => 'Active';

  @override
  String get loanStatusCLOSED => 'Repaid';

  @override
  String get loanStatusDEFAULTED => 'Defaulted';

  @override
  String get guarantorStatusPENDING => 'Pending';

  @override
  String get guarantorStatusCONSENTED => 'Accepted';

  @override
  String get guarantorStatusDECLINED => 'Declined';

  @override
  String get guarantorStatusRELEASED => 'Released';

  @override
  String termMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get applyTitle => 'Apply for a loan';

  @override
  String get loanProduct => 'Loan product';

  @override
  String productTerms(
    String rate,
    String method,
    int min,
    int max,
    String multiple,
  ) {
    return '$rate% · $method · $min–$max months · up to $multiple× deposits';
  }

  @override
  String get methodREDUCING_BALANCE => 'reducing balance';

  @override
  String get methodFLAT => 'flat rate';

  @override
  String get term => 'Term (months)';

  @override
  String termInvalid(int min, int max) {
    return 'Enter a term between $min and $max months.';
  }

  @override
  String get purpose => 'Purpose (optional)';

  @override
  String get applySubmit => 'Submit application';

  @override
  String get applied => 'Application created. Add your guarantors next.';

  @override
  String get loanDetail => 'Loan details';

  @override
  String get requested => 'Requested';

  @override
  String get interest => 'Interest';

  @override
  String get outstanding => 'Outstanding';

  @override
  String get guarantors => 'Guarantors';

  @override
  String get noGuarantors => 'No guarantors yet.';

  @override
  String guarantorsNeeded(int count) {
    return 'This product needs at least $count guarantors who accept.';
  }

  @override
  String get addGuarantor => 'Add guarantor';

  @override
  String get guarantorMemberNumber => 'Guarantor\'s member number';

  @override
  String get pledgedAmount => 'Amount they pledge';

  @override
  String get add => 'Add';

  @override
  String get submitForAppraisal => 'Submit for appraisal';

  @override
  String get submitted => 'Submitted for appraisal';

  @override
  String get schedule => 'Repayment schedule';

  @override
  String installment(int n, String date) {
    return '#$n · due $date';
  }

  @override
  String get paid => 'Paid';

  @override
  String get repayments => 'Repayments';

  @override
  String get automatedDecision => 'Automated decision';

  @override
  String get decisionNotes => 'Decision notes';

  @override
  String get repayHelp =>
      'To repay, pay through your SACCO\'s usual repayment channel. In-app loan repayment is coming soon.';

  @override
  String get dividendsTitle => 'Dividends & interest';

  @override
  String get noDistributions => 'No dividend or interest payments yet.';

  @override
  String get kindDIVIDEND => 'Dividend on shares';

  @override
  String get kindINTEREST => 'Interest on savings';

  @override
  String get gross => 'Gross';

  @override
  String get wht => 'Withholding tax';

  @override
  String get net => 'Net';

  @override
  String get entryStatusPROPOSED => 'Proposed';

  @override
  String get entryStatusPOSTED => 'Credited';

  @override
  String get entryStatusPAID => 'Paid out';

  @override
  String get profileTitle => 'My profile';

  @override
  String get kycVerified => 'KYC verified';

  @override
  String get kycPending => 'KYC pending';

  @override
  String get idNumber => 'ID number';

  @override
  String get contactDetails => 'Contact details';

  @override
  String get email => 'Email';

  @override
  String get address => 'Physical address';

  @override
  String get kycLockedHelp =>
      'Name and ID come from your KYC record. Contact your SACCO to correct them.';

  @override
  String get security => 'Security';

  @override
  String get biometricUnlock => 'Unlock with fingerprint / face';

  @override
  String get biometricUnavailable => 'Not available on this device';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm new password';

  @override
  String get passwordTooShort => 'Use at least 8 characters.';

  @override
  String get passwordMismatch => 'The new passwords don\'t match.';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get language => 'Language';

  @override
  String get logout => 'Log out';

  @override
  String get required => 'Required';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get all => 'All';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodBank => 'Bank';

  @override
  String get methodMobileMoney => 'Mobile money';

  @override
  String get myRoles => 'My roles';

  @override
  String get navWelfare => 'Welfare';

  @override
  String get searchMemberHint => 'Name, member no. or phone';

  @override
  String get noMembersFound => 'No members found.';

  @override
  String get payTitleWelfare => 'Pay welfare';

  @override
  String get purposeWELFARE_CONTRIBUTION => 'Welfare contribution';

  @override
  String get welfareTitle => 'Welfare';

  @override
  String get welfareMine => 'My welfare';

  @override
  String get welfareCases => 'Cases';

  @override
  String get welfareCounter => 'Counter';

  @override
  String get welfareRules => 'Rules';

  @override
  String get welfarePay => 'Pay welfare';

  @override
  String get welfarePayHelp =>
      'Pays off anything you owe for past cases first; the rest goes to your yearly welfare balance.';

  @override
  String get welfareBalance => 'Welfare balance';

  @override
  String get welfareBalanceHelp =>
      'Your yearly contribution not yet used. Cases are taken from here first.';

  @override
  String welfareYearly(int year) {
    return 'Paid for $year';
  }

  @override
  String get welfareOwed => 'You owe';

  @override
  String welfareOwedBanner(String amount) {
    return 'You owe $amount in welfare contributions';
  }

  @override
  String get welfareContributions => 'Case contributions';

  @override
  String get welfareNoContributions => 'No welfare contributions yet.';

  @override
  String welfareStillOwed(String amount) {
    return '$amount owed';
  }

  @override
  String get welfarePayments => 'Payments';

  @override
  String welfareToDues(String amount) {
    return '$amount to dues';
  }

  @override
  String welfareToBalance(String amount) {
    return '$amount to balance';
  }

  @override
  String get welfareYearlyAmount => 'Yearly welfare contribution';

  @override
  String get welfareCaseTypes => 'Case types';

  @override
  String get welfareRulesHelp =>
      'From the constitution: what each member contributes for each kind of case.';

  @override
  String get welfareNoRules => 'No welfare rules set up yet.';

  @override
  String get welfareBeneficiaryContributes =>
      'Affected member also contributes';

  @override
  String get welfarePerMember => 'per member';

  @override
  String welfarePerMemberAmount(String amount) {
    return '$amount per member';
  }

  @override
  String get welfareAddRule => 'Add case type';

  @override
  String get welfareEditRule => 'Edit case type';

  @override
  String get welfareRuleName => 'Name';

  @override
  String get welfareRuleNameHint => 'e.g. Member hospitalised';

  @override
  String get welfareRuleDescription => 'Constitution clause / notes';

  @override
  String get welfareContributionPerMember => 'Contribution per member';

  @override
  String get welfareYearEnd => 'Year end';

  @override
  String get welfareYearEndHelp =>
      'Moves members\' unused yearly welfare balances into the Welfare Fund.';

  @override
  String welfareCloseYear(int year) {
    return 'Close $year';
  }

  @override
  String welfareCloseYearTitle(int year) {
    return 'Close welfare year $year?';
  }

  @override
  String welfareCloseYearBody(int year) {
    return 'Every member\'s unused $year welfare balance will move to the Welfare Fund. This can\'t be undone.';
  }

  @override
  String welfareYearClosing(int year) {
    return 'Closing $year. Balances will update shortly.';
  }

  @override
  String welfareYearClosed(int year) {
    return '$year is closed.';
  }

  @override
  String get welfareFilterOpen => 'Open';

  @override
  String get welfareStatusPENDING_APPROVAL => 'Pending approval';

  @override
  String get welfareStatusAPPROVED => 'Approved';

  @override
  String get welfareStatusREJECTED => 'Rejected';

  @override
  String get welfareStatusCLOSED => 'Closed';

  @override
  String get welfareNewCase => 'New case';

  @override
  String get welfareNoCases => 'No cases here.';

  @override
  String welfareCollectedOf(String collected, String total) {
    return 'Collected $collected of $total';
  }

  @override
  String get welfarePickMember => 'Choose member';

  @override
  String get welfareCaseType => 'Case type';

  @override
  String welfareLevyPreview(String amount) {
    return 'On approval, every active member contributes $amount, taken from their welfare balance first.';
  }

  @override
  String get welfareAffectedPerson => 'Affected person';

  @override
  String get welfareAffectedPersonHint =>
      'If not the member, e.g. Mary W. (daughter)';

  @override
  String get welfareCaseDetails => 'Details';

  @override
  String get welfareNeedsApproval =>
      'A second person (e.g. the treasurer) must approve before members are charged.';

  @override
  String get welfareOpenCase => 'Open case';

  @override
  String get welfareCaseOpened => 'Case opened, awaiting approval';

  @override
  String get welfareCase => 'Welfare case';

  @override
  String get welfareBeneficiary => 'Member';

  @override
  String get welfareOpenedBy => 'Opened by';

  @override
  String get welfareDecidedBy => 'Decided by';

  @override
  String get welfareCollection => 'Collection';

  @override
  String get welfareLevyRunning => 'Charging members…';

  @override
  String get welfareMembersLevied => 'Members charged';

  @override
  String get welfareTotalLevied => 'Total charged';

  @override
  String get welfareCollected => 'Collected';

  @override
  String get welfareOutstanding => 'Still owed by members';

  @override
  String get welfarePaidOut => 'Paid out';

  @override
  String get welfareAvailable => 'Available to pay out';

  @override
  String get welfareApproveTitle => 'Approve case';

  @override
  String get welfareRejectTitle => 'Reject case';

  @override
  String get welfareReason => 'Reason';

  @override
  String get welfareNotesOptional => 'Notes (optional)';

  @override
  String get welfareApproved => 'Approved. Members are being charged.';

  @override
  String get welfareRejected => 'Case rejected';

  @override
  String get welfareApproveHelp =>
      'Approving charges every active member. You can\'t approve a case you opened.';

  @override
  String get welfareRecordPayout => 'Record payout';

  @override
  String welfarePayoutHelp(String amount) {
    return 'Record money already handed to the member. Up to $amount is available.';
  }

  @override
  String welfareMoreThanAvailable(String amount) {
    return 'Only $amount is available';
  }

  @override
  String get welfarePaidTo => 'Paid to';

  @override
  String get welfareReference => 'Reference / receipt no.';

  @override
  String get welfarePaidOn => 'Date paid';

  @override
  String get welfarePayoutRecorded => 'Payout recorded';

  @override
  String get welfareCloseCase => 'Close case';

  @override
  String get welfareCaseClosed => 'Case closed';

  @override
  String get welfarePayouts => 'Payouts';

  @override
  String get welfareWhoOwes => 'Member contributions';

  @override
  String get welfareOnlyOwing => 'Only members who still owe';

  @override
  String get welfareEveryonePaid => 'Everyone has paid.';

  @override
  String get welfareCounterHelp =>
      'Choose a member to see their welfare position and record a cash or bank payment.';

  @override
  String get welfareRecordPayment => 'Record payment';

  @override
  String get welfareAllocationHelp =>
      'Clears their oldest welfare dues first; the rest goes to their yearly balance.';

  @override
  String get welfarePaymentRecorded => 'Payment recorded';

  @override
  String get navLeader => 'Leader';

  @override
  String get leaderTitle => 'Leadership';

  @override
  String get leaderNeedsAttention => 'Needs your attention';

  @override
  String get leaderAllClear => 'Nothing waiting on you right now.';

  @override
  String get leaderModules => 'Your tools';

  @override
  String get leaderFinance => 'Finance';

  @override
  String get leaderFinanceHelp =>
      'Financial position, journal, chart of accounts';

  @override
  String get leaderReports => 'Reports';

  @override
  String get leaderReportsHelp => 'Financial statements and audit reports';

  @override
  String get leaderLoanDesk => 'Loan desk';

  @override
  String get leaderLoanDeskHelp =>
      'Appraise, approve, disburse, record repayments';

  @override
  String get leaderMembers => 'Members';

  @override
  String get leaderMembersHelp =>
      'Find a member, counter deposits and withdrawals';

  @override
  String get leaderMember => 'Member';

  @override
  String get leaderDistributions => 'Dividends & interest runs';

  @override
  String get leaderDistributionsHelp => 'Propose, approve and pay out';

  @override
  String get leaderWelfare => 'Welfare administration';

  @override
  String get leaderWelfareHelp => 'Cases, counter payments, rules, year end';

  @override
  String get taskLoansToAppraise => 'Loans waiting for appraisal';

  @override
  String get taskLoansToDecide => 'Loans waiting for a decision';

  @override
  String get taskLoansToDisburse => 'Approved loans to disburse';

  @override
  String get taskDistributionsToApprove =>
      'Dividend / interest runs to approve';

  @override
  String get taskWelfareToApprove => 'Welfare cases to approve';

  @override
  String get financeBalanced => 'Books balance';

  @override
  String get financeUnbalanced => 'Books do not balance';

  @override
  String get financeTrialBalanceHint => 'Tap to open the trial balance';

  @override
  String get financeCash => 'Cash and bank';

  @override
  String get financeCollectionsToday => 'Mobile money today';

  @override
  String get financeLoans => 'Loans outstanding';

  @override
  String get financePar => 'Portfolio at risk (>30d)';

  @override
  String get financeWelfareFund => 'Welfare fund';

  @override
  String get financeMembers => 'Active members';

  @override
  String get financeThisYear => 'This year';

  @override
  String get financeIncome => 'Income';

  @override
  String get financeExpenses => 'Expenses';

  @override
  String get financeSurplus => 'Surplus / (deficit)';

  @override
  String get financeTools => 'Tools';

  @override
  String get financeJournal => 'Journal';

  @override
  String get financeJournalHelp => 'Every posted entry; reverse mistakes';

  @override
  String get financeNewEntry => 'New journal entry';

  @override
  String get financeNewEntryHelp => 'Expenses, fees, bank charges';

  @override
  String get financeChart => 'Chart of accounts';

  @override
  String get financeChartHelp => 'Accounts and adding new ones';

  @override
  String journalReversedBy(String ref) {
    return 'reversed by $ref';
  }

  @override
  String journalReverses(String ref) {
    return 'reverses $ref';
  }

  @override
  String get journalDate => 'Date';

  @override
  String get journalPostedBy => 'Posted by';

  @override
  String get journalReversesLabel => 'Reverses';

  @override
  String get journalReversedByLabel => 'Reversed by';

  @override
  String get journalLines => 'Lines';

  @override
  String get debitShort => 'Dr';

  @override
  String get creditShort => 'Cr';

  @override
  String get debit => 'Debit';

  @override
  String get credit => 'Credit';

  @override
  String get journalReverse => 'Reverse this entry';

  @override
  String get journalReverseTitle => 'Reverse entry';

  @override
  String get journalReverseHelp =>
      'Posted entries are never edited or deleted. This posts an equal and opposite entry, keeping both on record.';

  @override
  String get journalReversed => 'Entry reversed';

  @override
  String get journalDescription => 'Description';

  @override
  String get journalControlHelp =>
      'Member accounts (savings, shares, loans, welfare) aren\'t listed; they change only through their own screens.';

  @override
  String get journalAccount => 'Account';

  @override
  String get journalMemo => 'Line note (optional)';

  @override
  String get journalAddLine => 'Add line';

  @override
  String get journalDifference => 'Difference';

  @override
  String get journalPost => 'Post entry';

  @override
  String get journalPosted => 'Entry posted';

  @override
  String get journalNeedsDescription => 'Add a description.';

  @override
  String get journalNeedsTwoLines =>
      'An entry needs at least two lines with an account and amount.';

  @override
  String get journalOneSidePerLine =>
      'Each line is either a debit or a credit, not both.';

  @override
  String get journalNotBalanced => 'Debits and credits must be equal.';

  @override
  String get chartAdd => 'Add account';

  @override
  String get chartCode => 'Code';

  @override
  String get chartName => 'Name';

  @override
  String get chartNameHint => 'e.g. Office rent';

  @override
  String get chartType => 'Type';

  @override
  String get chartAdded => 'Account added';

  @override
  String get chartControl => 'Member control account';

  @override
  String get typeAsset => 'Assets';

  @override
  String get typeLiability => 'Liabilities';

  @override
  String get typeEquity => 'Equity';

  @override
  String get typeIncome => 'Income';

  @override
  String get typeExpense => 'Expenses';

  @override
  String get reportsIntro =>
      'Figures come straight from the ledger. Share any report as a spreadsheet (CSV) for internal, external or Auditor-General audits.';

  @override
  String get reportsNone => 'No reports are available for your role.';

  @override
  String get reportTrialBalance => 'Trial balance';

  @override
  String get reportTrialBalanceHelp =>
      'Every account\'s debit or credit balance';

  @override
  String get reportBalanceSheet => 'Statement of financial position';

  @override
  String get reportBalanceSheetHelp => 'Assets, liabilities and equity';

  @override
  String get reportIncomeStatement => 'Income statement';

  @override
  String get reportIncomeStatementHelp =>
      'Income, expenses and surplus for a period';

  @override
  String get reportGeneralLedger => 'General ledger';

  @override
  String get reportGeneralLedgerHelp =>
      'One account\'s transactions with running balance';

  @override
  String get reportJournal => 'Journal (day book)';

  @override
  String get reportJournalHelp => 'Every entry, who posted it, reversals';

  @override
  String get reportMemberBalances => 'Member balances & reconciliation';

  @override
  String get reportMemberBalancesHelp =>
      'Each member\'s balances, checked against control accounts';

  @override
  String get reportLoanPortfolio => 'Loan portfolio & arrears';

  @override
  String get reportLoanPortfolioHelp =>
      'Outstanding loans, ageing and portfolio at risk';

  @override
  String get reportCollections => 'Mobile money collections';

  @override
  String get reportCollectionsHelp => 'M-Pesa / Selcom payments by outcome';

  @override
  String get reportDistributions => 'Dividend & interest register';

  @override
  String get reportDistributionsHelp => 'Declared amounts with withholding tax';

  @override
  String get reportExport => 'Share as spreadsheet';

  @override
  String get reportAsAt => 'As at';

  @override
  String get reportFrom => 'From';

  @override
  String get reportTo => 'To';

  @override
  String reportGeneratedBy(String name, String currency) {
    return 'Prepared by $name · amounts in $currency';
  }

  @override
  String get reportNoRows => 'Nothing in this period.';

  @override
  String get runPropose => 'Propose run';

  @override
  String get noRuns => 'No dividend or interest runs yet.';

  @override
  String runMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get runPeriod => 'Period';

  @override
  String get runRate => 'Rate';

  @override
  String get runMembersLabel => 'Members';

  @override
  String get runProposedBy => 'Proposed by';

  @override
  String get runWhtUnconfirmed =>
      'Withholding tax rates haven\'t been confirmed by a tax adviser yet.';

  @override
  String get runApproveTitle => 'Approve run?';

  @override
  String runApproveBody(String amount) {
    return 'This posts $amount net to members\' accounts in the ledger.';
  }

  @override
  String get runApproveHelp => 'You can\'t approve a run you proposed.';

  @override
  String get runApproved => 'Run approved and posted';

  @override
  String get runRejectTitle => 'Reject run';

  @override
  String get runRejected => 'Run rejected';

  @override
  String get runPayout => 'Pay out by mobile money';

  @override
  String runPayoutBody(String amount) {
    return 'Send $amount to members\' phones now?';
  }

  @override
  String get runPayoutStarted => 'Payouts started';

  @override
  String get runRatePercent => 'Rate (%)';

  @override
  String get runRatePercentOptional => 'Rate (%) - blank uses the product rate';

  @override
  String get runDescription => 'Description, e.g. AGM FY2025 dividend';

  @override
  String get runProposeHelp =>
      'A different leader must approve before anything is posted.';

  @override
  String get runRateRequired => 'Enter the dividend rate.';

  @override
  String get runProposed => 'Run proposed, awaiting approval';

  @override
  String get welfareRequiredProduct => 'Choose a savings product.';

  @override
  String get queueAppraise => 'To appraise';

  @override
  String get queueDecide => 'To decide';

  @override
  String get queueDisburse => 'To disburse';

  @override
  String get queueActive => 'Active';

  @override
  String get queueEmpty => 'No loans here.';

  @override
  String queueDaysOverdue(int days) {
    return '$days days overdue';
  }

  @override
  String get queueArrears => 'Arrears';

  @override
  String get queueAppraisedBy => 'Appraised by';

  @override
  String get queueAppraisalNotes => 'Appraisal notes';

  @override
  String queuePledged(String amount) {
    return 'Total pledged by guarantors: $amount';
  }

  @override
  String get queueAppraiseAction => 'Record appraisal';

  @override
  String get queueAppraised => 'Appraisal recorded';

  @override
  String get queueApproved => 'Loan approved';

  @override
  String get queueRejected => 'Loan rejected';

  @override
  String get queueDisburseAction => 'Disburse loan';

  @override
  String get queueToSavings => 'To savings';

  @override
  String get queueDisbursed => 'Disbursement sent';

  @override
  String get queueAwaitingProvider =>
      'Waiting for the mobile money provider to confirm.';

  @override
  String get queueRecordRepayment => 'Record repayment';

  @override
  String get queueRepaymentRecorded => 'Repayment recorded';

  @override
  String get counterActions => 'Counter';

  @override
  String get counterWithdraw => 'Withdraw';

  @override
  String counterWithdrawConfirm(String amount, String name) {
    return 'Pay out $amount to $name?';
  }

  @override
  String get counterFromAccount => 'From account';

  @override
  String get counterRecorded => 'Recorded';

  @override
  String get counterVerifyKyc => 'Verify KYC';

  @override
  String get counterVerifyKycBody =>
      'Confirm you\'ve checked this member\'s ID documents.';

  @override
  String get counterPledged => 'Locked as guarantor';

  @override
  String get counterLimitedView => 'Your role shows member details only.';

  @override
  String get brandTagline => 'Empowerment Group';

  @override
  String get connecting => 'Connecting…';

  @override
  String get navFinance => 'Finance';

  @override
  String get navLoanDesk => 'Loan desk';

  @override
  String get navMembers => 'Members';

  @override
  String get navReports => 'Reports';

  @override
  String get navDividends => 'Dividends';

  @override
  String get navMore => 'More';

  @override
  String get moreProfileHelp => 'Photo, password, language';

  @override
  String get photoTake => 'Take a photo';

  @override
  String get photoChoose => 'Choose from gallery';

  @override
  String get photoPickFailed => 'Couldn\'t open that photo. Try another one.';

  @override
  String get photoUploading => 'Uploading photo…';

  @override
  String get photoUpdated => 'Profile photo updated';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get submit => 'Submit';

  @override
  String get upload => 'Upload';

  @override
  String get uploaded => 'Uploaded';

  @override
  String get replace => 'Replace';

  @override
  String get field => 'Detail';

  @override
  String get now => 'Now';

  @override
  String get newValue => 'Change to';

  @override
  String get onRecord => 'Details';

  @override
  String get myDetailsTitle => 'My details & family';

  @override
  String get myDetailsHelp => 'Personal details, ID, family register';

  @override
  String get personalDetails => 'Personal details';

  @override
  String get basicDetails => 'Contact & work';

  @override
  String get basicDetailsHelp => 'You can update these any time.';

  @override
  String get idDocuments => 'ID card';

  @override
  String get idFront => 'ID front';

  @override
  String get idBack => 'ID back';

  @override
  String get tapToScan => 'Tap to scan';

  @override
  String get idScanFrontTip =>
      'Lay your ID flat in good light, fill the frame, avoid glare.';

  @override
  String get idScanBackTip => 'Now the back of the ID card.';

  @override
  String get idNotRead =>
      'We couldn\'t read the ID number from the photo. You can still upload it; the Secretary will check it.';

  @override
  String idReadMatches(String number) {
    return 'Read ID number $number. It matches your record.';
  }

  @override
  String idReadDifferent(String read, String record) {
    return 'Read ID number $read, but your record says $record. Check the photo, or request a change to your ID number.';
  }

  @override
  String get idNumberMatches => 'Number matches';

  @override
  String get idNumberMismatch => 'Number differs';

  @override
  String idNumberRead(String number) {
    return 'Read: $number';
  }

  @override
  String get documentUploaded => 'Document uploaded';

  @override
  String get documentOnFile => 'Document on file';

  @override
  String get documentLoadFailed => 'Couldn\'t load this document.';

  @override
  String get pdfOnFile => 'This PDF is on file; open it on the web to view.';

  @override
  String get familyRegister => 'Family register';

  @override
  String get familyRegisterHelp =>
      'Only people approved here are covered by welfare.';

  @override
  String get familyEmpty => 'No family members registered yet.';

  @override
  String get addFamilyMember => 'Add family member';

  @override
  String get familyFormHelp =>
      'The Secretary approves each person before they\'re covered by welfare. Add a birth certificate or ID afterwards.';

  @override
  String get fieldFirstName => 'First name';

  @override
  String get fieldLastName => 'Surname';

  @override
  String get fieldOtherNames => 'Other names';

  @override
  String get fieldFullName => 'Full name';

  @override
  String get fieldDateOfBirth => 'Date of birth';

  @override
  String get fieldGender => 'Gender';

  @override
  String get fieldIdType => 'ID type';

  @override
  String get fieldMaritalStatus => 'Marital status';

  @override
  String get fieldRelationship => 'Relationship';

  @override
  String get fieldBirthCert => 'Birth certificate no.';

  @override
  String get fieldNextOfKin => 'Next of kin';

  @override
  String get fieldDeceased => 'Deceased';

  @override
  String get fieldOccupation => 'Occupation';

  @override
  String get fieldEmployer => 'Employer';

  @override
  String get fieldCounty => 'County / region';

  @override
  String get relSpouse => 'Spouse';

  @override
  String get relChild => 'Child';

  @override
  String get relParent => 'Parent';

  @override
  String get relParentInLaw => 'Parent-in-law';

  @override
  String get relSibling => 'Sibling';

  @override
  String get relSelf => 'Member themself';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderMale => 'Male';

  @override
  String get genderOther => 'Other';

  @override
  String get maritalSingle => 'Single';

  @override
  String get maritalMarried => 'Married';

  @override
  String get maritalWidowed => 'Widowed';

  @override
  String get maritalDivorced => 'Divorced / separated';

  @override
  String get idTypeNational => 'National ID';

  @override
  String get idTypeHuduma => 'Huduma Namba';

  @override
  String get idTypeNida => 'NIDA';

  @override
  String get idTypePassport => 'Passport';

  @override
  String ageYears(int age) {
    return '$age yrs';
  }

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusAwaitingApproval => 'Awaiting approval';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get requestChange => 'Request a change';

  @override
  String get requestRemoval => 'Request removal';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String get requestCancelled => 'Request cancelled';

  @override
  String get changeAwaitingApproval => 'Change awaiting approval';

  @override
  String get changeSentForApproval => 'Sent to the Secretary for approval';

  @override
  String get sendForApproval => 'Send for approval';

  @override
  String get changeReason => 'Reason for the change (helps approval)';

  @override
  String get nothingChanged => 'Nothing has changed.';

  @override
  String get personalChangeHelp =>
      'Changes to these details are checked and approved by the Secretary before they apply. Upload your ID if the number or names change.';

  @override
  String get childDobRequired =>
      'A child\'s date of birth is needed for welfare cover.';

  @override
  String get uploadBirthCert => 'Upload birth certificate';

  @override
  String get uploadIdPhoto => 'Upload ID photo';

  @override
  String removalHelp(String name) {
    return 'Removing $name means welfare no longer covers them. The Secretary must approve.';
  }

  @override
  String get myRequests => 'My requests';

  @override
  String get submitForApproval => 'Submit for approval';

  @override
  String get submitForApprovalTitle => 'Submit your details?';

  @override
  String get submitForApprovalBody =>
      'The Secretary will check your details and ID. Once approved, changes need approval.';

  @override
  String get submittedForApproval => 'Submitted for approval';

  @override
  String get profileDraft => 'Complete your profile';

  @override
  String get profileDraftHelp =>
      'Check your details, scan your ID and add your family, then submit.';

  @override
  String get profilePending => 'Awaiting approval';

  @override
  String get profilePendingHelp => 'The Secretary is checking your details.';

  @override
  String get profileVerified => 'Profile verified';

  @override
  String get profileVerifiedHelp =>
      'Your details are locked. Changes need the Secretary\'s approval.';

  @override
  String get profileActionNeeded => 'Action needed';

  @override
  String get profileNotSubmitted => 'Not submitted';

  @override
  String get completeProfileTitle => 'Complete your profile';

  @override
  String get completeProfileBody =>
      'Add your ID and family so welfare can cover them.';

  @override
  String get navApprovals => 'Approvals';

  @override
  String get approvalsTitle => 'Member approvals';

  @override
  String get approvalsHelp => 'Profile, ID and family changes to approve';

  @override
  String get approvalsEmpty => 'Nothing waiting for approval.';

  @override
  String get firstProfileApproval => 'New profile to verify';

  @override
  String memberSays(String note) {
    return 'Member\'s note: $note';
  }

  @override
  String get whatChanges => 'What changes';

  @override
  String get documentsToCheck => 'Documents to check';

  @override
  String get noDocumentsYet => 'No documents uploaded yet.';

  @override
  String get compareIdHelp =>
      'Compare the ID photo with the details before approving. The number check is a guide only.';

  @override
  String get removalWarning =>
      'Approving removes this person from welfare cover.';

  @override
  String get rejectReasonForMember => 'Reason (the member will see this)';

  @override
  String get changeApproved => 'Approved';

  @override
  String get changeRejected => 'Rejected';

  @override
  String get tableMember => 'Member';

  @override
  String get tableStatus => 'Status';

  @override
  String get tableProfile => 'Profile';

  @override
  String tableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get memberDormant => 'Dormant';

  @override
  String get memberExited => 'Exited';

  @override
  String get welfareCovers => 'Who this covers';

  @override
  String get welfareCoversRequired =>
      'Choose at least one person this case type covers.';

  @override
  String get welfareChildMaxAge => 'Child age limit (optional)';

  @override
  String get welfareChildMaxAgeHint => 'e.g. 18';

  @override
  String get welfarePickAffected => 'Choose who the case is for.';

  @override
  String get welfareNobodyCovered =>
      'Nobody on this member\'s register is covered by this case type.';

  @override
  String get welfareNobodyCoveredHelp =>
      'The member must add the person to their family register and have it approved first.';

  @override
  String get welfareRegisterOnlyHelp =>
      'Only approved family-register entries are covered.';

  @override
  String get navMeetings => 'Meetings';

  @override
  String get navActivity => 'Inactive';

  @override
  String get meetingsTitle => 'Meetings';

  @override
  String get meetingsHelp => 'Schedule meetings and take the register';

  @override
  String get myMeetingsHelp => 'Upcoming meetings, apologies, my attendance';

  @override
  String get meetingsUpcoming => 'Upcoming';

  @override
  String get meetingsPast => 'Past';

  @override
  String get meetingsNoneUpcoming => 'No upcoming meetings.';

  @override
  String get meetingsNonePast => 'No past meetings yet.';

  @override
  String get meetingSchedule => 'Schedule meeting';

  @override
  String get meetingType => 'Meeting type';

  @override
  String get meetingAgm => 'Annual general meeting';

  @override
  String get meetingSgm => 'Special general meeting';

  @override
  String get meetingMonthly => 'Monthly members\' meeting';

  @override
  String get meetingCommittee => 'Committee meeting';

  @override
  String get meetingBoard => 'Board meeting';

  @override
  String get meetingTitleLabel => 'Title';

  @override
  String get meetingTitleHint => 'e.g. October monthly meeting';

  @override
  String get meetingTime => 'Time';

  @override
  String get meetingVenue => 'Venue';

  @override
  String get meetingAgenda => 'Agenda';

  @override
  String get meetingSendNotice => 'SMS notice to all members';

  @override
  String get meetingSendNoticeHelp => 'Members can send an apology in the app.';

  @override
  String get meetingNotCounted =>
      'Committee and board meetings don\'t count towards the attendance rule.';

  @override
  String get meetingScheduled => 'Meeting scheduled';

  @override
  String get meetingScheduledNotified =>
      'Meeting scheduled and members notified';

  @override
  String get meetingCancel => 'Cancel meeting';

  @override
  String get meetingCancelBody =>
      'Cancel this meeting? It won\'t count for attendance.';

  @override
  String get meetingCancelled => 'Cancelled';

  @override
  String meetingApologiesIn(int count) {
    return '$count apologies';
  }

  @override
  String get attPresent => 'Present';

  @override
  String get attLate => 'Late';

  @override
  String get attApology => 'Apology';

  @override
  String get attAbsent => 'Absent';

  @override
  String get attNotMarked => 'Not marked';

  @override
  String get registerSaved => 'Register saved';

  @override
  String get registerClose => 'Close register';

  @override
  String registerCloseBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count members aren\'t marked and will be recorded absent without apology.',
      one:
          '1 member isn\'t marked and will be recorded absent without apology.',
      zero: 'Everyone is marked. Close the register?',
    );
    return '$_temp0';
  }

  @override
  String get registerClosed => 'Register closed';

  @override
  String get registerHeldHelp =>
      'This register is closed. You can still correct a mark.';

  @override
  String apologyReasonShown(String reason) {
    return 'Apology: $reason';
  }

  @override
  String get sendApology => 'Send apology';

  @override
  String get apologyReason => 'Reason';

  @override
  String get apologyHelp =>
      'An apology means this absence won\'t count against you.';

  @override
  String get apologySent => 'Apology sent';

  @override
  String get myAttendance => 'My attendance';

  @override
  String missedMeetingsStreak(int count, int limit) {
    return '$count meetings missed in a row without apology (limit $limit)';
  }

  @override
  String get missedMeetingsHelp =>
      'Attend the next meeting or send an apology to stay active.';

  @override
  String get atRiskTitle => 'Your membership may become dormant';

  @override
  String atRiskMonths(int count) {
    return '$count months without a monthly contribution';
  }

  @override
  String atRiskMeetings(int count) {
    return '$count meetings missed without apology';
  }

  @override
  String get dormantTitle => 'Your membership is dormant';

  @override
  String get dormantBody =>
      'You can view and pay, but not borrow or guarantee, and welfare doesn\'t cover you. Make your monthly contribution or attend a meeting to reactivate.';

  @override
  String get taskProfileChanges => 'Profile changes to approve';

  @override
  String get taskMembersToArchive => 'Inactive members to review';

  @override
  String get activityTitle => 'Inactive members';

  @override
  String get activityHelp => 'Archive or reactivate members; inactivity rules';

  @override
  String get activityFlagged => 'To review';

  @override
  String get activityDormant => 'Dormant';

  @override
  String get activityRules => 'Rules';

  @override
  String get activityFlaggedHelp =>
      'Members the monthly check found past a limit. They were warned by SMS one step before.';

  @override
  String get activityNoneFlagged => 'Nobody to review.';

  @override
  String get activityKeepActive => 'Keep active';

  @override
  String get activityKeepActiveHelp => 'E.g. they\'ve agreed a payment plan.';

  @override
  String get activityKept => 'Kept active';

  @override
  String get activityArchive => 'Make dormant';

  @override
  String activityArchiveBody(String name) {
    return '$name will be dormant: they can view and pay, but can\'t borrow or guarantee, and aren\'t levied or covered for welfare. They come back automatically when they contribute or attend.';
  }

  @override
  String get activityArchived => 'Member made dormant';

  @override
  String get activityDormantHelp =>
      'They return automatically when they contribute to monthly savings or attend a meeting.';

  @override
  String get activityNoneDormant => 'No dormant members.';

  @override
  String get activityReactivate => 'Reactivate';

  @override
  String get activityReactivated => 'Member reactivated';

  @override
  String get activityRunNow => 'Run the check now';

  @override
  String activityCheckDone(int flagged, int warned) {
    return 'Check done: $flagged flagged, $warned warned by SMS';
  }

  @override
  String activityLastRun(String date) {
    return 'Last run: $date';
  }

  @override
  String get activityNeverRun => 'Not run yet.';

  @override
  String get activityScheduleHelp =>
      'It also runs automatically on the 1st of each month.';

  @override
  String get activityWarnBeforeLimit =>
      'The warning must come before the limit.';

  @override
  String get ruleContributions => 'Missed monthly contributions';

  @override
  String get ruleContributionsHelp =>
      'Months in a row with no deposit into mandatory monthly savings.';

  @override
  String get ruleWarnAfterMonths => 'SMS warning after (months)';

  @override
  String get ruleArchiveAfterMonths => 'Review for dormancy after (months)';

  @override
  String get ruleMinAmount => 'Minimum monthly amount';

  @override
  String get ruleMinAmountHelp => '0 = any amount counts.';

  @override
  String get ruleMeetings => 'Missed meetings';

  @override
  String get ruleMeetingsHelp =>
      'General meetings in a row missed without apology.';

  @override
  String get ruleWarnAfterMeetings => 'SMS warning after (meetings)';

  @override
  String get ruleArchiveAfterMeetings => 'Review for dormancy after (meetings)';

  @override
  String get navAdmin => 'Admin';

  @override
  String get adminTitle => 'Admin & support';

  @override
  String get adminHelp => 'Users, passwords, positions, audit log';

  @override
  String get adminUsers => 'Users & support';

  @override
  String get adminUsersHelp =>
      'Find anyone, reset a password, switch a login off or on';

  @override
  String get adminPositions => 'Positions & roles';

  @override
  String get adminPositionsHelp =>
      'Give people positions, remove them, create new ones';

  @override
  String get adminAudit => 'Audit log';

  @override
  String get adminAuditHelp =>
      'Who did or viewed what, when, where and on which device';

  @override
  String get adminSecurity => 'Sign-ins & security';

  @override
  String get adminSecurityHelp =>
      'Sign-ins, failed attempts, password resets, role changes';

  @override
  String get allow => 'Allow';

  @override
  String get notNow => 'Not now';

  @override
  String get anyDate => 'Any date';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get share => 'Share';

  @override
  String get remove => 'Remove';

  @override
  String get notes => 'Notes';

  @override
  String get downloadCsv => 'Download CSV';

  @override
  String get idScan => 'Scan ID';

  @override
  String idScanRead(String number) {
    return 'Read ID number $number';
  }

  @override
  String get paymentMethodLabel => 'Paid by';

  @override
  String get receiptReference => 'Receipt / reference';

  @override
  String get taskApplicationsToApprove => 'New members to approve';

  @override
  String get profileChangesTab => 'Profile changes';

  @override
  String get applicationsTitle => 'New members';

  @override
  String get applicationsEmpty => 'No applications waiting.';

  @override
  String applicationBy(String name, String date) {
    return 'by $name, $date';
  }

  @override
  String applicationDecidedBy(String name, String date) {
    return 'Decided by $name, $date';
  }

  @override
  String get applicationSubmitted => 'Sent for approval';

  @override
  String applicationApproved(String number) {
    return 'Approved - member no. $number';
  }

  @override
  String get applicationCancelled => 'Cancelled';

  @override
  String get approveApplication => 'Approve new member';

  @override
  String approveApplicationBody(String name) {
    return '$name becomes a member on probation and gets a login with a temporary password.';
  }

  @override
  String get cancelApplication => 'Cancel application';

  @override
  String get cancelApplicationBody =>
      'Withdraw this application? Return any fee collected.';

  @override
  String get cantApproveOwnApplication =>
      'You registered this applicant, so someone else must approve.';

  @override
  String get registerMember => 'Register member';

  @override
  String get registerMemberHelp =>
      'The Chairperson (or another approver) must approve before the member is created. Their member number and login are issued on approval.';

  @override
  String get registrationFee => 'Registration fee';

  @override
  String registrationFeeIs(String amount) {
    return 'The registration fee is $amount.';
  }

  @override
  String get registrationFeeZeroHelp => '0 = no fee';

  @override
  String get feeCollectedNow => 'Fee collected now';

  @override
  String get feeCollectedHelp =>
      'Recorded in the books only once approved; hand it back if rejected.';

  @override
  String get feeNotCollected => 'Not collected at registration.';

  @override
  String memberNumberIs(String number) {
    return 'Member no. $number';
  }

  @override
  String get recordRegistrationFee => 'Record registration fee';

  @override
  String get registrationFeeRecorded => 'Registration fee recorded';

  @override
  String get payRegistrationFee => 'Pay registration fee';

  @override
  String get payTitleRegistrationFee => 'Pay registration fee';

  @override
  String get registrationFeePayHelp =>
      'One-off and non-refundable. Needed for full membership.';

  @override
  String get membershipRules => 'Membership rules';

  @override
  String membershipRulesSummary(String fee, int months) {
    return 'Fee $fee · verified after $months monthly contributions in a row';
  }

  @override
  String get verificationMonthsLabel =>
      'Consecutive monthly contributions to be verified';

  @override
  String get probation => 'Probation';

  @override
  String get probationTitle => 'New member - on probation';

  @override
  String get probationBody =>
      'You become a full member once these are done. Until then you can\'t borrow, guarantee, get welfare cover, vote or hold office.';

  @override
  String probationFeePaid(String amount) {
    return 'Registration fee $amount paid';
  }

  @override
  String probationFeeDue(String amount) {
    return 'Registration fee: $amount to pay';
  }

  @override
  String probationMonths(int done, int total) {
    return 'Monthly contributions in a row: $done of $total';
  }

  @override
  String get probationNoVote => 'New member on probation - can\'t vote yet';

  @override
  String get tempPasswordTitle => 'Choose your own password';

  @override
  String get tempPasswordHelp =>
      'You signed in with a temporary password. Choose a new one only you know.';

  @override
  String get tempPasswordCurrent => 'Temporary password';

  @override
  String get tempPasswordIssued => 'Temporary password';

  @override
  String get tempPasswordOnce =>
      'Shown only now. They\'ll choose their own when they sign in.';

  @override
  String tempPasswordShareText(String name, String phone, String password) {
    return 'Inuka West: $name, sign in with your phone $phone and temporary password $password. You\'ll then choose your own.';
  }

  @override
  String get temporaryPasswordPending => 'Temporary password';

  @override
  String get pickPerson => 'Choose a person';

  @override
  String get searchPeopleHint => 'Name, phone or member no.';

  @override
  String get noPeopleFound => 'Nobody found.';

  @override
  String get disabledLogins => 'Disabled logins';

  @override
  String get loginActive => 'Login active';

  @override
  String get loginDisabled => 'Login disabled';

  @override
  String get loginEnabled => 'Login re-enabled';

  @override
  String get disableLogin => 'Disable login';

  @override
  String get enableLogin => 'Re-enable login';

  @override
  String disableLoginBody(String name) {
    return '$name is signed out now and can\'t sign in until re-enabled. Their records stay.';
  }

  @override
  String enableLoginBody(String name) {
    return '$name will be able to sign in again.';
  }

  @override
  String get resetPassword => 'Reset password';

  @override
  String resetPasswordBody(String name) {
    return '$name gets a temporary password to share with them, and is signed out on every phone.';
  }

  @override
  String get supportActions => 'Support';

  @override
  String get viewActivity => 'View activity';

  @override
  String get lastSignIn => 'Last sign-in';

  @override
  String get lastActive => 'Last active';

  @override
  String get neverSeen => 'Never';

  @override
  String get seenJustNow => 'Just now';

  @override
  String seenMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String seenHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String seenDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get devicesAndPlaces => 'Devices & places';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get positionsHeld => 'Positions';

  @override
  String get givePosition => 'Give a position';

  @override
  String givePositionTo(String name) {
    return 'Give $name a position';
  }

  @override
  String get positionsHelp =>
      'Each office has a holder and an assistant, so one can check the other. New members on probation can\'t hold office.';

  @override
  String get officesAndCommittees => 'Offices & committees';

  @override
  String get staffRoles => 'Staff roles';

  @override
  String holdersCount(int count) {
    return '$count holding';
  }

  @override
  String holdersOfMax(int count, int max) {
    return '$count of $max';
  }

  @override
  String get positionFull => 'Full';

  @override
  String get vacant => 'Vacant';

  @override
  String get assignPerson => 'Assign someone';

  @override
  String assistantTo(String name) {
    return 'Assistant to $name';
  }

  @override
  String positionAssigned(String name, String position) {
    return '$name is now $position';
  }

  @override
  String get positionRemoved => 'Removed from the position';

  @override
  String get removeFromPosition => 'Remove from position';

  @override
  String removeFromPositionBody(String name, String position) {
    return 'Remove $name from $position? They lose its access now.';
  }

  @override
  String get jobTitleOptional => 'Title (optional)';

  @override
  String get jobTitleHint => 'e.g. Treasurer 2025-2027';

  @override
  String get newPosition => 'New position';

  @override
  String get newPositionHelp =>
      'E.g. Disciplinary Secretary or Youth Representative. An assistant gets the same permissions as the office it assists.';

  @override
  String get positionName => 'Name';

  @override
  String get positionNameHint => 'e.g. Youth Representative';

  @override
  String get positionDuties => 'Duties';

  @override
  String get assistantOfLabel => 'Assistant to';

  @override
  String get assistantOfHelp => 'Makes this the assistant of an office.';

  @override
  String get notAnAssistant => 'Not an assistant';

  @override
  String get copyPermissionsFrom => 'Same permissions as';

  @override
  String get copyPermissionsHelp =>
      'Start from an existing role\'s permissions.';

  @override
  String get noPermissionsYet => 'None yet';

  @override
  String get maxHoldersLabel => 'How many people can hold it';

  @override
  String get noLimit => 'No limit';

  @override
  String get createPosition => 'Create position';

  @override
  String get positionCreated => 'Position created';

  @override
  String get auditSearchHint => 'Search who, what, where, device or IP';

  @override
  String get auditSecurityOnly => 'Sign-ins & security only';

  @override
  String get auditEmpty => 'Nothing recorded for this filter.';

  @override
  String get auditWho => 'Who';

  @override
  String get auditWhen => 'When';

  @override
  String get auditAction => 'Action';

  @override
  String get auditRecord => 'Record';

  @override
  String get auditResult => 'Result';

  @override
  String get auditOk => 'Allowed';

  @override
  String auditRefused(int code) {
    return 'Refused ($code)';
  }

  @override
  String get auditWhere => 'Where';

  @override
  String get auditCoordinates => 'Coordinates';

  @override
  String get auditIp => 'IP address';

  @override
  String get auditDevice => 'Device';

  @override
  String get auditRequest => 'Request';

  @override
  String get locationAskTitle => 'Protect your account';

  @override
  String get locationAskBody =>
      'Inuka West can note the approximate area you sign in from, so the SACCO can spot someone else using your account. It\'s only kept in the SACCO\'s audit log. You can say no.';

  @override
  String greetMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String greetAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String greetEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String get greetMorningPlain => 'Good morning';

  @override
  String get greetAfternoonPlain => 'Good afternoon';

  @override
  String get greetEveningPlain => 'Good evening';

  @override
  String get loginIdLabel => 'Phone or member number';

  @override
  String get loginIdHint => '0712 345 678 or IW-26-00123';

  @override
  String get meetingDocuments => 'Documents';

  @override
  String get meetingMinutes => 'Minutes';

  @override
  String get meetingRegister => 'Register';

  @override
  String get docAgenda => 'Agenda';

  @override
  String get docNotice => 'Notice';

  @override
  String get docReport => 'Report';

  @override
  String get docFinancials => 'Financial statements';

  @override
  String get docSignedMinutes => 'Signed minutes';

  @override
  String get docAttachment => 'Attachment';

  @override
  String get addDocument => 'Add document';

  @override
  String get chooseFile => 'Choose a file';

  @override
  String get chooseFileHelp => 'PDF, Word, Excel, PowerPoint or a photo';

  @override
  String get photoOfPaper => 'Photo of a printed paper';

  @override
  String get documentTitle => 'Title';

  @override
  String get documentType => 'Type';

  @override
  String get documentAdded => 'Document added';

  @override
  String get noDocuments => 'No documents yet.';

  @override
  String documentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents',
      one: '1 document',
    );
    return '$_temp0';
  }

  @override
  String get withdrawDocument => 'Withdraw document';

  @override
  String get withdrawDocumentHelp =>
      'It stays on record (for the audit trail) but members no longer see it.';

  @override
  String get withdrawReason => 'Reason';

  @override
  String get documentWithdrawn => 'Document withdrawn';

  @override
  String withdrawnBecause(String reason) {
    return 'Withdrawn: $reason';
  }

  @override
  String get confidentialPapers => 'Committee/board papers - leaders only.';

  @override
  String get minutesDraft => 'Draft';

  @override
  String get minutesAwaitingApproval => 'Awaiting approval';

  @override
  String get minutesApproved => 'Minutes approved';

  @override
  String get minutesNone => 'Not written yet';

  @override
  String get minutesAvailable => 'Minutes available';

  @override
  String minutesSubmittedBy(String name, String date) {
    return 'Written by $name, $date';
  }

  @override
  String minutesApprovedBy(String name, String date) {
    return 'Approved by $name, $date';
  }

  @override
  String minutesSentBack(String comment) {
    return 'Sent back: $comment';
  }

  @override
  String get minutesAfterMeeting => 'Minutes are written after the meeting.';

  @override
  String get minutesNotYetApproved => 'The minutes aren\'t approved yet.';

  @override
  String get writeMinutes => 'Write minutes';

  @override
  String get editMinutes => 'Edit minutes';

  @override
  String get submitMinutes => 'Send for approval';

  @override
  String get submitMinutesBody =>
      'The Chairperson (or another approver) will review them. You can\'t edit while they\'re waiting.';

  @override
  String get minutesSubmitted => 'Minutes sent for approval';

  @override
  String get cantApproveOwnMinutes =>
      'You sent these minutes, so someone else must approve them.';

  @override
  String get sendBackMinutes => 'Send back';

  @override
  String get whatNeedsChanging => 'What needs changing?';

  @override
  String get minutesReturned => 'Sent back to the Secretary';

  @override
  String get approveMinutes => 'Approve';

  @override
  String get approveMinutesBody =>
      'Approved minutes are locked and shared with members (general meetings). Corrections are then added as addenda.';

  @override
  String get minutesPdf => 'PDF';

  @override
  String get addAddendum => 'Add addendum';

  @override
  String get addendumText => 'Correction or note';

  @override
  String get addendumHelp =>
      'Approved minutes can\'t be edited; an addendum is added below them with your name and the date.';

  @override
  String get addendumAdded => 'Addendum added';

  @override
  String addendumBy(String name, String date) {
    return 'Addendum - $name, $date';
  }

  @override
  String get minutesSaved => 'Draft saved';

  @override
  String get saveDraft => 'Save draft';

  @override
  String get addMinuteItem => 'Add numbered minute';

  @override
  String get minutesHint => 'Write the minutes...';

  @override
  String get unsavedMinutes => 'Save your changes?';

  @override
  String get unsavedMinutesBody => 'You have changes that aren\'t saved.';

  @override
  String get taskMinutesToApprove => 'Minutes to approve';
}
