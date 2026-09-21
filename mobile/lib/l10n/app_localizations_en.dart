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
}
