import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Inuka West'**
  String get appTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your connection and try again.'**
  String get networkError;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get genericError;

  /// No description provided for @findSaccoTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your SACCO'**
  String get findSaccoTitle;

  /// No description provided for @findSaccoBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the code your SACCO gave you. It\'s the first part of its web address, for example \"shirika\".'**
  String get findSaccoBody;

  /// No description provided for @saccoCode.
  ///
  /// In en, this message translates to:
  /// **'SACCO code'**
  String get saccoCode;

  /// No description provided for @saccoNotFound.
  ///
  /// In en, this message translates to:
  /// **'No SACCO found with that code.'**
  String get saccoNotFound;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginTitle;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'+2547...'**
  String get phoneHint;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @loginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginSubmit;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Check your details and try again.'**
  String get loginError;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get sessionExpired;

  /// No description provided for @noMemberRecord.
  ///
  /// In en, this message translates to:
  /// **'This login has no member record and no staff tools available on mobile. Ask your SACCO administrator to assign you a role.'**
  String get noMemberRecord;

  /// No description provided for @notYourSacco.
  ///
  /// In en, this message translates to:
  /// **'Not your SACCO?'**
  String get notYourSacco;

  /// No description provided for @changeSacco.
  ///
  /// In en, this message translates to:
  /// **'Change SACCO'**
  String get changeSacco;

  /// No description provided for @unlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockTitle;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock your SACCO account'**
  String get unlockReason;

  /// No description provided for @unlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockButton;

  /// No description provided for @usePassword.
  ///
  /// In en, this message translates to:
  /// **'Log in with password instead'**
  String get usePassword;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get navSavings;

  /// No description provided for @navLoans.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get navLoans;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcome(String name);

  /// No description provided for @memberNumber.
  ///
  /// In en, this message translates to:
  /// **'Member no. {number}'**
  String memberNumber(String number);

  /// No description provided for @shareCapital.
  ///
  /// In en, this message translates to:
  /// **'Share capital'**
  String get shareCapital;

  /// No description provided for @shareCapitalHelp.
  ///
  /// In en, this message translates to:
  /// **'Your ownership stake. Earns dividends; not withdrawable.'**
  String get shareCapitalHelp;

  /// No description provided for @savingsTotal.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savingsTotal;

  /// No description provided for @savingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Withdrawable deposits. Earn interest and set how much you can borrow.'**
  String get savingsHelp;

  /// No description provided for @loanOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Loan balance'**
  String get loanOutstanding;

  /// No description provided for @noActiveLoans.
  ///
  /// In en, this message translates to:
  /// **'No active loans'**
  String get noActiveLoans;

  /// No description provided for @nextPayment.
  ///
  /// In en, this message translates to:
  /// **'Next payment {amount} due {date}'**
  String nextPayment(String amount, String date);

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue {days} days · {amount}'**
  String overdue(int days, String amount);

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @actionDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get actionDeposit;

  /// No description provided for @actionContribute.
  ///
  /// In en, this message translates to:
  /// **'Buy shares'**
  String get actionContribute;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply for loan'**
  String get actionApply;

  /// No description provided for @actionDividends.
  ///
  /// In en, this message translates to:
  /// **'Dividends'**
  String get actionDividends;

  /// No description provided for @guaranteeRequestsBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member has asked you to guarantee their loan} other{{count} members have asked you to guarantee their loans}}'**
  String guaranteeRequestsBanner(int count);

  /// No description provided for @recentPayments.
  ///
  /// In en, this message translates to:
  /// **'Recent mobile-money payments'**
  String get recentPayments;

  /// No description provided for @savingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings & shares'**
  String get savingsTitle;

  /// No description provided for @savingsAccounts.
  ///
  /// In en, this message translates to:
  /// **'Savings accounts'**
  String get savingsAccounts;

  /// No description provided for @noSavingsAccounts.
  ///
  /// In en, this message translates to:
  /// **'No savings accounts yet. Make a deposit to open one.'**
  String get noSavingsAccounts;

  /// No description provided for @contributions.
  ///
  /// In en, this message translates to:
  /// **'Contributions'**
  String get contributions;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get noTransactions;

  /// No description provided for @txDEPOSIT.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get txDEPOSIT;

  /// No description provided for @txWITHDRAWAL.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get txWITHDRAWAL;

  /// No description provided for @txCONTRIBUTION.
  ///
  /// In en, this message translates to:
  /// **'Share contribution'**
  String get txCONTRIBUTION;

  /// No description provided for @withdrawalsAtBranch.
  ///
  /// In en, this message translates to:
  /// **'Withdrawals are handled by your SACCO.'**
  String get withdrawalsAtBranch;

  /// No description provided for @pledgedLocked.
  ///
  /// In en, this message translates to:
  /// **'{amount} locked as guarantee for other members\' loans'**
  String pledgedLocked(String amount);

  /// No description provided for @payTitleDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit to savings'**
  String get payTitleDeposit;

  /// No description provided for @payTitleContribute.
  ///
  /// In en, this message translates to:
  /// **'Buy shares'**
  String get payTitleContribute;

  /// No description provided for @savingsProduct.
  ///
  /// In en, this message translates to:
  /// **'Savings product'**
  String get savingsProduct;

  /// No description provided for @selectProduct.
  ///
  /// In en, this message translates to:
  /// **'Select a product'**
  String get selectProduct;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @amountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than 0 with at most 2 decimals.'**
  String get amountInvalid;

  /// No description provided for @payFromPhone.
  ///
  /// In en, this message translates to:
  /// **'Pay from phone number'**
  String get payFromPhone;

  /// No description provided for @mobileMoneyHelp.
  ///
  /// In en, this message translates to:
  /// **'You\'ll get a mobile-money prompt on this phone to confirm.'**
  String get mobileMoneyHelp;

  /// No description provided for @payButton.
  ///
  /// In en, this message translates to:
  /// **'Send payment request'**
  String get payButton;

  /// No description provided for @payWaiting.
  ///
  /// In en, this message translates to:
  /// **'Check your phone and enter your PIN to confirm…'**
  String get payWaiting;

  /// No description provided for @paySuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get paySuccess;

  /// No description provided for @payFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get payFailed;

  /// No description provided for @payCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get payCancelled;

  /// No description provided for @payStillPending.
  ///
  /// In en, this message translates to:
  /// **'Still waiting for confirmation. It will show in your statement once your provider confirms it.'**
  String get payStillPending;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt {receipt}'**
  String receipt(String receipt);

  /// No description provided for @statusPENDING.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPENDING;

  /// No description provided for @statusSUCCESS.
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get statusSUCCESS;

  /// No description provided for @statusFAILED.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFAILED;

  /// No description provided for @statusCANCELLED.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCANCELLED;

  /// No description provided for @purposeSAVINGS_DEPOSIT.
  ///
  /// In en, this message translates to:
  /// **'Savings deposit'**
  String get purposeSAVINGS_DEPOSIT;

  /// No description provided for @purposeSHARE_CONTRIBUTION.
  ///
  /// In en, this message translates to:
  /// **'Share contribution'**
  String get purposeSHARE_CONTRIBUTION;

  /// No description provided for @loansTitle.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get loansTitle;

  /// No description provided for @myLoans.
  ///
  /// In en, this message translates to:
  /// **'My loans'**
  String get myLoans;

  /// No description provided for @noLoans.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t applied for a loan yet.'**
  String get noLoans;

  /// No description provided for @guaranteeRequests.
  ///
  /// In en, this message translates to:
  /// **'Guarantee requests'**
  String get guaranteeRequests;

  /// No description provided for @guaranteeFor.
  ///
  /// In en, this message translates to:
  /// **'{name} asks you to pledge {amount}'**
  String guaranteeFor(String name, String amount);

  /// No description provided for @guaranteeWarning.
  ///
  /// In en, this message translates to:
  /// **'Accepting locks this amount of your deposits until their loan is repaid. You won\'t be able to withdraw or borrow against it.'**
  String get guaranteeWarning;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @confirmAcceptTitle.
  ///
  /// In en, this message translates to:
  /// **'Pledge your deposits?'**
  String get confirmAcceptTitle;

  /// No description provided for @loanStatusPENDING_GUARANTORS.
  ///
  /// In en, this message translates to:
  /// **'Awaiting guarantors'**
  String get loanStatusPENDING_GUARANTORS;

  /// No description provided for @loanStatusPENDING_APPRAISAL.
  ///
  /// In en, this message translates to:
  /// **'Pending appraisal'**
  String get loanStatusPENDING_APPRAISAL;

  /// No description provided for @loanStatusAPPRAISED.
  ///
  /// In en, this message translates to:
  /// **'Appraised'**
  String get loanStatusAPPRAISED;

  /// No description provided for @loanStatusAPPROVED.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get loanStatusAPPROVED;

  /// No description provided for @loanStatusREJECTED.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get loanStatusREJECTED;

  /// No description provided for @loanStatusDISBURSED.
  ///
  /// In en, this message translates to:
  /// **'Disbursement pending'**
  String get loanStatusDISBURSED;

  /// No description provided for @loanStatusACTIVE.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get loanStatusACTIVE;

  /// No description provided for @loanStatusCLOSED.
  ///
  /// In en, this message translates to:
  /// **'Repaid'**
  String get loanStatusCLOSED;

  /// No description provided for @loanStatusDEFAULTED.
  ///
  /// In en, this message translates to:
  /// **'Defaulted'**
  String get loanStatusDEFAULTED;

  /// No description provided for @guarantorStatusPENDING.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get guarantorStatusPENDING;

  /// No description provided for @guarantorStatusCONSENTED.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get guarantorStatusCONSENTED;

  /// No description provided for @guarantorStatusDECLINED.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get guarantorStatusDECLINED;

  /// No description provided for @guarantorStatusRELEASED.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get guarantorStatusRELEASED;

  /// No description provided for @termMonths.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{1 month} other{{months} months}}'**
  String termMonths(int months);

  /// No description provided for @applyTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply for a loan'**
  String get applyTitle;

  /// No description provided for @loanProduct.
  ///
  /// In en, this message translates to:
  /// **'Loan product'**
  String get loanProduct;

  /// No description provided for @productTerms.
  ///
  /// In en, this message translates to:
  /// **'{rate}% · {method} · {min}–{max} months · up to {multiple}× deposits'**
  String productTerms(
    String rate,
    String method,
    int min,
    int max,
    String multiple,
  );

  /// No description provided for @methodREDUCING_BALANCE.
  ///
  /// In en, this message translates to:
  /// **'reducing balance'**
  String get methodREDUCING_BALANCE;

  /// No description provided for @methodFLAT.
  ///
  /// In en, this message translates to:
  /// **'flat rate'**
  String get methodFLAT;

  /// No description provided for @term.
  ///
  /// In en, this message translates to:
  /// **'Term (months)'**
  String get term;

  /// No description provided for @termInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a term between {min} and {max} months.'**
  String termInvalid(int min, int max);

  /// No description provided for @purpose.
  ///
  /// In en, this message translates to:
  /// **'Purpose (optional)'**
  String get purpose;

  /// No description provided for @applySubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit application'**
  String get applySubmit;

  /// No description provided for @applied.
  ///
  /// In en, this message translates to:
  /// **'Application created. Add your guarantors next.'**
  String get applied;

  /// No description provided for @loanDetail.
  ///
  /// In en, this message translates to:
  /// **'Loan details'**
  String get loanDetail;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @interest.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get interest;

  /// No description provided for @outstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstanding;

  /// No description provided for @guarantors.
  ///
  /// In en, this message translates to:
  /// **'Guarantors'**
  String get guarantors;

  /// No description provided for @noGuarantors.
  ///
  /// In en, this message translates to:
  /// **'No guarantors yet.'**
  String get noGuarantors;

  /// No description provided for @guarantorsNeeded.
  ///
  /// In en, this message translates to:
  /// **'This product needs at least {count} guarantors who accept.'**
  String guarantorsNeeded(int count);

  /// No description provided for @addGuarantor.
  ///
  /// In en, this message translates to:
  /// **'Add guarantor'**
  String get addGuarantor;

  /// No description provided for @guarantorMemberNumber.
  ///
  /// In en, this message translates to:
  /// **'Guarantor\'s member number'**
  String get guarantorMemberNumber;

  /// No description provided for @pledgedAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount they pledge'**
  String get pledgedAmount;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @submitForAppraisal.
  ///
  /// In en, this message translates to:
  /// **'Submit for appraisal'**
  String get submitForAppraisal;

  /// No description provided for @submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted for appraisal'**
  String get submitted;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Repayment schedule'**
  String get schedule;

  /// No description provided for @installment.
  ///
  /// In en, this message translates to:
  /// **'#{n} · due {date}'**
  String installment(int n, String date);

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @repayments.
  ///
  /// In en, this message translates to:
  /// **'Repayments'**
  String get repayments;

  /// No description provided for @automatedDecision.
  ///
  /// In en, this message translates to:
  /// **'Automated decision'**
  String get automatedDecision;

  /// No description provided for @decisionNotes.
  ///
  /// In en, this message translates to:
  /// **'Decision notes'**
  String get decisionNotes;

  /// No description provided for @repayHelp.
  ///
  /// In en, this message translates to:
  /// **'To repay, pay through your SACCO\'s usual repayment channel. In-app loan repayment is coming soon.'**
  String get repayHelp;

  /// No description provided for @dividendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Dividends & interest'**
  String get dividendsTitle;

  /// No description provided for @noDistributions.
  ///
  /// In en, this message translates to:
  /// **'No dividend or interest payments yet.'**
  String get noDistributions;

  /// No description provided for @kindDIVIDEND.
  ///
  /// In en, this message translates to:
  /// **'Dividend on shares'**
  String get kindDIVIDEND;

  /// No description provided for @kindINTEREST.
  ///
  /// In en, this message translates to:
  /// **'Interest on savings'**
  String get kindINTEREST;

  /// No description provided for @gross.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get gross;

  /// No description provided for @wht.
  ///
  /// In en, this message translates to:
  /// **'Withholding tax'**
  String get wht;

  /// No description provided for @net.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get net;

  /// No description provided for @entryStatusPROPOSED.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get entryStatusPROPOSED;

  /// No description provided for @entryStatusPOSTED.
  ///
  /// In en, this message translates to:
  /// **'Credited'**
  String get entryStatusPOSTED;

  /// No description provided for @entryStatusPAID.
  ///
  /// In en, this message translates to:
  /// **'Paid out'**
  String get entryStatusPAID;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get profileTitle;

  /// No description provided for @kycVerified.
  ///
  /// In en, this message translates to:
  /// **'KYC verified'**
  String get kycVerified;

  /// No description provided for @kycPending.
  ///
  /// In en, this message translates to:
  /// **'KYC pending'**
  String get kycPending;

  /// No description provided for @idNumber.
  ///
  /// In en, this message translates to:
  /// **'ID number'**
  String get idNumber;

  /// No description provided for @contactDetails.
  ///
  /// In en, this message translates to:
  /// **'Contact details'**
  String get contactDetails;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Physical address'**
  String get address;

  /// No description provided for @kycLockedHelp.
  ///
  /// In en, this message translates to:
  /// **'Name and ID come from your KYC record. Contact your SACCO to correct them.'**
  String get kycLockedHelp;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @biometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint / face'**
  String get biometricUnlock;

  /// No description provided for @biometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get biometricUnavailable;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get passwordTooShort;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The new passwords don\'t match.'**
  String get passwordMismatch;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get methodBank;

  /// No description provided for @methodMobileMoney.
  ///
  /// In en, this message translates to:
  /// **'Mobile money'**
  String get methodMobileMoney;

  /// No description provided for @myRoles.
  ///
  /// In en, this message translates to:
  /// **'My roles'**
  String get myRoles;

  /// No description provided for @navWelfare.
  ///
  /// In en, this message translates to:
  /// **'Welfare'**
  String get navWelfare;

  /// No description provided for @searchMemberHint.
  ///
  /// In en, this message translates to:
  /// **'Name, member no. or phone'**
  String get searchMemberHint;

  /// No description provided for @noMembersFound.
  ///
  /// In en, this message translates to:
  /// **'No members found.'**
  String get noMembersFound;

  /// No description provided for @payTitleWelfare.
  ///
  /// In en, this message translates to:
  /// **'Pay welfare'**
  String get payTitleWelfare;

  /// No description provided for @purposeWELFARE_CONTRIBUTION.
  ///
  /// In en, this message translates to:
  /// **'Welfare contribution'**
  String get purposeWELFARE_CONTRIBUTION;

  /// No description provided for @welfareTitle.
  ///
  /// In en, this message translates to:
  /// **'Welfare'**
  String get welfareTitle;

  /// No description provided for @welfareMine.
  ///
  /// In en, this message translates to:
  /// **'My welfare'**
  String get welfareMine;

  /// No description provided for @welfareCases.
  ///
  /// In en, this message translates to:
  /// **'Cases'**
  String get welfareCases;

  /// No description provided for @welfareCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get welfareCounter;

  /// No description provided for @welfareRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get welfareRules;

  /// No description provided for @welfarePay.
  ///
  /// In en, this message translates to:
  /// **'Pay welfare'**
  String get welfarePay;

  /// No description provided for @welfarePayHelp.
  ///
  /// In en, this message translates to:
  /// **'Pays off anything you owe for past cases first; the rest goes to your yearly welfare balance.'**
  String get welfarePayHelp;

  /// No description provided for @welfareBalance.
  ///
  /// In en, this message translates to:
  /// **'Welfare balance'**
  String get welfareBalance;

  /// No description provided for @welfareBalanceHelp.
  ///
  /// In en, this message translates to:
  /// **'Your yearly contribution not yet used. Cases are taken from here first.'**
  String get welfareBalanceHelp;

  /// No description provided for @welfareYearly.
  ///
  /// In en, this message translates to:
  /// **'Paid for {year}'**
  String welfareYearly(int year);

  /// No description provided for @welfareOwed.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get welfareOwed;

  /// No description provided for @welfareOwedBanner.
  ///
  /// In en, this message translates to:
  /// **'You owe {amount} in welfare contributions'**
  String welfareOwedBanner(String amount);

  /// No description provided for @welfareContributions.
  ///
  /// In en, this message translates to:
  /// **'Case contributions'**
  String get welfareContributions;

  /// No description provided for @welfareNoContributions.
  ///
  /// In en, this message translates to:
  /// **'No welfare contributions yet.'**
  String get welfareNoContributions;

  /// No description provided for @welfareStillOwed.
  ///
  /// In en, this message translates to:
  /// **'{amount} owed'**
  String welfareStillOwed(String amount);

  /// No description provided for @welfarePayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get welfarePayments;

  /// No description provided for @welfareToDues.
  ///
  /// In en, this message translates to:
  /// **'{amount} to dues'**
  String welfareToDues(String amount);

  /// No description provided for @welfareToBalance.
  ///
  /// In en, this message translates to:
  /// **'{amount} to balance'**
  String welfareToBalance(String amount);

  /// No description provided for @welfareYearlyAmount.
  ///
  /// In en, this message translates to:
  /// **'Yearly welfare contribution'**
  String get welfareYearlyAmount;

  /// No description provided for @welfareCaseTypes.
  ///
  /// In en, this message translates to:
  /// **'Case types'**
  String get welfareCaseTypes;

  /// No description provided for @welfareRulesHelp.
  ///
  /// In en, this message translates to:
  /// **'From the constitution: what each member contributes for each kind of case.'**
  String get welfareRulesHelp;

  /// No description provided for @welfareNoRules.
  ///
  /// In en, this message translates to:
  /// **'No welfare rules set up yet.'**
  String get welfareNoRules;

  /// No description provided for @welfareBeneficiaryContributes.
  ///
  /// In en, this message translates to:
  /// **'Affected member also contributes'**
  String get welfareBeneficiaryContributes;

  /// No description provided for @welfarePerMember.
  ///
  /// In en, this message translates to:
  /// **'per member'**
  String get welfarePerMember;

  /// No description provided for @welfarePerMemberAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} per member'**
  String welfarePerMemberAmount(String amount);

  /// No description provided for @welfareAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add case type'**
  String get welfareAddRule;

  /// No description provided for @welfareEditRule.
  ///
  /// In en, this message translates to:
  /// **'Edit case type'**
  String get welfareEditRule;

  /// No description provided for @welfareRuleName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get welfareRuleName;

  /// No description provided for @welfareRuleNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Member hospitalised'**
  String get welfareRuleNameHint;

  /// No description provided for @welfareRuleDescription.
  ///
  /// In en, this message translates to:
  /// **'Constitution clause / notes'**
  String get welfareRuleDescription;

  /// No description provided for @welfareContributionPerMember.
  ///
  /// In en, this message translates to:
  /// **'Contribution per member'**
  String get welfareContributionPerMember;

  /// No description provided for @welfareYearEnd.
  ///
  /// In en, this message translates to:
  /// **'Year end'**
  String get welfareYearEnd;

  /// No description provided for @welfareYearEndHelp.
  ///
  /// In en, this message translates to:
  /// **'Moves members\' unused yearly welfare balances into the Welfare Fund.'**
  String get welfareYearEndHelp;

  /// No description provided for @welfareCloseYear.
  ///
  /// In en, this message translates to:
  /// **'Close {year}'**
  String welfareCloseYear(int year);

  /// No description provided for @welfareCloseYearTitle.
  ///
  /// In en, this message translates to:
  /// **'Close welfare year {year}?'**
  String welfareCloseYearTitle(int year);

  /// No description provided for @welfareCloseYearBody.
  ///
  /// In en, this message translates to:
  /// **'Every member\'s unused {year} welfare balance will move to the Welfare Fund. This can\'t be undone.'**
  String welfareCloseYearBody(int year);

  /// No description provided for @welfareYearClosing.
  ///
  /// In en, this message translates to:
  /// **'Closing {year}. Balances will update shortly.'**
  String welfareYearClosing(int year);

  /// No description provided for @welfareYearClosed.
  ///
  /// In en, this message translates to:
  /// **'{year} is closed.'**
  String welfareYearClosed(int year);

  /// No description provided for @welfareFilterOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get welfareFilterOpen;

  /// No description provided for @welfareStatusPENDING_APPROVAL.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get welfareStatusPENDING_APPROVAL;

  /// No description provided for @welfareStatusAPPROVED.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get welfareStatusAPPROVED;

  /// No description provided for @welfareStatusREJECTED.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get welfareStatusREJECTED;

  /// No description provided for @welfareStatusCLOSED.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get welfareStatusCLOSED;

  /// No description provided for @welfareNewCase.
  ///
  /// In en, this message translates to:
  /// **'New case'**
  String get welfareNewCase;

  /// No description provided for @welfareNoCases.
  ///
  /// In en, this message translates to:
  /// **'No cases here.'**
  String get welfareNoCases;

  /// No description provided for @welfareCollectedOf.
  ///
  /// In en, this message translates to:
  /// **'Collected {collected} of {total}'**
  String welfareCollectedOf(String collected, String total);

  /// No description provided for @welfarePickMember.
  ///
  /// In en, this message translates to:
  /// **'Choose member'**
  String get welfarePickMember;

  /// No description provided for @welfareCaseType.
  ///
  /// In en, this message translates to:
  /// **'Case type'**
  String get welfareCaseType;

  /// No description provided for @welfareLevyPreview.
  ///
  /// In en, this message translates to:
  /// **'On approval, every active member contributes {amount}, taken from their welfare balance first.'**
  String welfareLevyPreview(String amount);

  /// No description provided for @welfareAffectedPerson.
  ///
  /// In en, this message translates to:
  /// **'Affected person'**
  String get welfareAffectedPerson;

  /// No description provided for @welfareAffectedPersonHint.
  ///
  /// In en, this message translates to:
  /// **'If not the member, e.g. Mary W. (daughter)'**
  String get welfareAffectedPersonHint;

  /// No description provided for @welfareCaseDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get welfareCaseDetails;

  /// No description provided for @welfareNeedsApproval.
  ///
  /// In en, this message translates to:
  /// **'A second person (e.g. the treasurer) must approve before members are charged.'**
  String get welfareNeedsApproval;

  /// No description provided for @welfareOpenCase.
  ///
  /// In en, this message translates to:
  /// **'Open case'**
  String get welfareOpenCase;

  /// No description provided for @welfareCaseOpened.
  ///
  /// In en, this message translates to:
  /// **'Case opened, awaiting approval'**
  String get welfareCaseOpened;

  /// No description provided for @welfareCase.
  ///
  /// In en, this message translates to:
  /// **'Welfare case'**
  String get welfareCase;

  /// No description provided for @welfareBeneficiary.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get welfareBeneficiary;

  /// No description provided for @welfareOpenedBy.
  ///
  /// In en, this message translates to:
  /// **'Opened by'**
  String get welfareOpenedBy;

  /// No description provided for @welfareDecidedBy.
  ///
  /// In en, this message translates to:
  /// **'Decided by'**
  String get welfareDecidedBy;

  /// No description provided for @welfareCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get welfareCollection;

  /// No description provided for @welfareLevyRunning.
  ///
  /// In en, this message translates to:
  /// **'Charging members…'**
  String get welfareLevyRunning;

  /// No description provided for @welfareMembersLevied.
  ///
  /// In en, this message translates to:
  /// **'Members charged'**
  String get welfareMembersLevied;

  /// No description provided for @welfareTotalLevied.
  ///
  /// In en, this message translates to:
  /// **'Total charged'**
  String get welfareTotalLevied;

  /// No description provided for @welfareCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get welfareCollected;

  /// No description provided for @welfareOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Still owed by members'**
  String get welfareOutstanding;

  /// No description provided for @welfarePaidOut.
  ///
  /// In en, this message translates to:
  /// **'Paid out'**
  String get welfarePaidOut;

  /// No description provided for @welfareAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available to pay out'**
  String get welfareAvailable;

  /// No description provided for @welfareApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve case'**
  String get welfareApproveTitle;

  /// No description provided for @welfareRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject case'**
  String get welfareRejectTitle;

  /// No description provided for @welfareReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get welfareReason;

  /// No description provided for @welfareNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get welfareNotesOptional;

  /// No description provided for @welfareApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved. Members are being charged.'**
  String get welfareApproved;

  /// No description provided for @welfareRejected.
  ///
  /// In en, this message translates to:
  /// **'Case rejected'**
  String get welfareRejected;

  /// No description provided for @welfareApproveHelp.
  ///
  /// In en, this message translates to:
  /// **'Approving charges every active member. You can\'t approve a case you opened.'**
  String get welfareApproveHelp;

  /// No description provided for @welfareRecordPayout.
  ///
  /// In en, this message translates to:
  /// **'Record payout'**
  String get welfareRecordPayout;

  /// No description provided for @welfarePayoutHelp.
  ///
  /// In en, this message translates to:
  /// **'Record money already handed to the member. Up to {amount} is available.'**
  String welfarePayoutHelp(String amount);

  /// No description provided for @welfareMoreThanAvailable.
  ///
  /// In en, this message translates to:
  /// **'Only {amount} is available'**
  String welfareMoreThanAvailable(String amount);

  /// No description provided for @welfarePaidTo.
  ///
  /// In en, this message translates to:
  /// **'Paid to'**
  String get welfarePaidTo;

  /// No description provided for @welfareReference.
  ///
  /// In en, this message translates to:
  /// **'Reference / receipt no.'**
  String get welfareReference;

  /// No description provided for @welfarePaidOn.
  ///
  /// In en, this message translates to:
  /// **'Date paid'**
  String get welfarePaidOn;

  /// No description provided for @welfarePayoutRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payout recorded'**
  String get welfarePayoutRecorded;

  /// No description provided for @welfareCloseCase.
  ///
  /// In en, this message translates to:
  /// **'Close case'**
  String get welfareCloseCase;

  /// No description provided for @welfareCaseClosed.
  ///
  /// In en, this message translates to:
  /// **'Case closed'**
  String get welfareCaseClosed;

  /// No description provided for @welfarePayouts.
  ///
  /// In en, this message translates to:
  /// **'Payouts'**
  String get welfarePayouts;

  /// No description provided for @welfareWhoOwes.
  ///
  /// In en, this message translates to:
  /// **'Member contributions'**
  String get welfareWhoOwes;

  /// No description provided for @welfareOnlyOwing.
  ///
  /// In en, this message translates to:
  /// **'Only members who still owe'**
  String get welfareOnlyOwing;

  /// No description provided for @welfareEveryonePaid.
  ///
  /// In en, this message translates to:
  /// **'Everyone has paid.'**
  String get welfareEveryonePaid;

  /// No description provided for @welfareCounterHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a member to see their welfare position and record a cash or bank payment.'**
  String get welfareCounterHelp;

  /// No description provided for @welfareRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get welfareRecordPayment;

  /// No description provided for @welfareAllocationHelp.
  ///
  /// In en, this message translates to:
  /// **'Clears their oldest welfare dues first; the rest goes to their yearly balance.'**
  String get welfareAllocationHelp;

  /// No description provided for @welfarePaymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get welfarePaymentRecorded;

  /// No description provided for @navLeader.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get navLeader;

  /// No description provided for @leaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Leadership'**
  String get leaderTitle;

  /// No description provided for @leaderNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs your attention'**
  String get leaderNeedsAttention;

  /// No description provided for @leaderAllClear.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting on you right now.'**
  String get leaderAllClear;

  /// No description provided for @leaderModules.
  ///
  /// In en, this message translates to:
  /// **'Your tools'**
  String get leaderModules;

  /// No description provided for @leaderFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get leaderFinance;

  /// No description provided for @leaderFinanceHelp.
  ///
  /// In en, this message translates to:
  /// **'Financial position, journal, chart of accounts'**
  String get leaderFinanceHelp;

  /// No description provided for @leaderReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get leaderReports;

  /// No description provided for @leaderReportsHelp.
  ///
  /// In en, this message translates to:
  /// **'Financial statements and audit reports'**
  String get leaderReportsHelp;

  /// No description provided for @leaderLoanDesk.
  ///
  /// In en, this message translates to:
  /// **'Loan desk'**
  String get leaderLoanDesk;

  /// No description provided for @leaderLoanDeskHelp.
  ///
  /// In en, this message translates to:
  /// **'Appraise, approve, disburse, record repayments'**
  String get leaderLoanDeskHelp;

  /// No description provided for @leaderMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get leaderMembers;

  /// No description provided for @leaderMembersHelp.
  ///
  /// In en, this message translates to:
  /// **'Find a member, counter deposits and withdrawals'**
  String get leaderMembersHelp;

  /// No description provided for @leaderMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get leaderMember;

  /// No description provided for @leaderDistributions.
  ///
  /// In en, this message translates to:
  /// **'Dividends & interest runs'**
  String get leaderDistributions;

  /// No description provided for @leaderDistributionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Propose, approve and pay out'**
  String get leaderDistributionsHelp;

  /// No description provided for @leaderWelfare.
  ///
  /// In en, this message translates to:
  /// **'Welfare administration'**
  String get leaderWelfare;

  /// No description provided for @leaderWelfareHelp.
  ///
  /// In en, this message translates to:
  /// **'Cases, counter payments, rules, year end'**
  String get leaderWelfareHelp;

  /// No description provided for @taskLoansToAppraise.
  ///
  /// In en, this message translates to:
  /// **'Loans waiting for appraisal'**
  String get taskLoansToAppraise;

  /// No description provided for @taskLoansToDecide.
  ///
  /// In en, this message translates to:
  /// **'Loans waiting for a decision'**
  String get taskLoansToDecide;

  /// No description provided for @taskLoansToDisburse.
  ///
  /// In en, this message translates to:
  /// **'Approved loans to disburse'**
  String get taskLoansToDisburse;

  /// No description provided for @taskDistributionsToApprove.
  ///
  /// In en, this message translates to:
  /// **'Dividend / interest runs to approve'**
  String get taskDistributionsToApprove;

  /// No description provided for @taskWelfareToApprove.
  ///
  /// In en, this message translates to:
  /// **'Welfare cases to approve'**
  String get taskWelfareToApprove;

  /// No description provided for @financeBalanced.
  ///
  /// In en, this message translates to:
  /// **'Books balance'**
  String get financeBalanced;

  /// No description provided for @financeUnbalanced.
  ///
  /// In en, this message translates to:
  /// **'Books do not balance'**
  String get financeUnbalanced;

  /// No description provided for @financeTrialBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to open the trial balance'**
  String get financeTrialBalanceHint;

  /// No description provided for @financeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash and bank'**
  String get financeCash;

  /// No description provided for @financeCollectionsToday.
  ///
  /// In en, this message translates to:
  /// **'Mobile money today'**
  String get financeCollectionsToday;

  /// No description provided for @financeLoans.
  ///
  /// In en, this message translates to:
  /// **'Loans outstanding'**
  String get financeLoans;

  /// No description provided for @financePar.
  ///
  /// In en, this message translates to:
  /// **'Portfolio at risk (>30d)'**
  String get financePar;

  /// No description provided for @financeWelfareFund.
  ///
  /// In en, this message translates to:
  /// **'Welfare fund'**
  String get financeWelfareFund;

  /// No description provided for @financeMembers.
  ///
  /// In en, this message translates to:
  /// **'Active members'**
  String get financeMembers;

  /// No description provided for @financeThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get financeThisYear;

  /// No description provided for @financeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get financeIncome;

  /// No description provided for @financeExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get financeExpenses;

  /// No description provided for @financeSurplus.
  ///
  /// In en, this message translates to:
  /// **'Surplus / (deficit)'**
  String get financeSurplus;

  /// No description provided for @financeTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get financeTools;

  /// No description provided for @financeJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get financeJournal;

  /// No description provided for @financeJournalHelp.
  ///
  /// In en, this message translates to:
  /// **'Every posted entry; reverse mistakes'**
  String get financeJournalHelp;

  /// No description provided for @financeNewEntry.
  ///
  /// In en, this message translates to:
  /// **'New journal entry'**
  String get financeNewEntry;

  /// No description provided for @financeNewEntryHelp.
  ///
  /// In en, this message translates to:
  /// **'Expenses, fees, bank charges'**
  String get financeNewEntryHelp;

  /// No description provided for @financeChart.
  ///
  /// In en, this message translates to:
  /// **'Chart of accounts'**
  String get financeChart;

  /// No description provided for @financeChartHelp.
  ///
  /// In en, this message translates to:
  /// **'Accounts and adding new ones'**
  String get financeChartHelp;

  /// No description provided for @journalReversedBy.
  ///
  /// In en, this message translates to:
  /// **'reversed by {ref}'**
  String journalReversedBy(String ref);

  /// No description provided for @journalReverses.
  ///
  /// In en, this message translates to:
  /// **'reverses {ref}'**
  String journalReverses(String ref);

  /// No description provided for @journalDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get journalDate;

  /// No description provided for @journalPostedBy.
  ///
  /// In en, this message translates to:
  /// **'Posted by'**
  String get journalPostedBy;

  /// No description provided for @journalReversesLabel.
  ///
  /// In en, this message translates to:
  /// **'Reverses'**
  String get journalReversesLabel;

  /// No description provided for @journalReversedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Reversed by'**
  String get journalReversedByLabel;

  /// No description provided for @journalLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get journalLines;

  /// No description provided for @debitShort.
  ///
  /// In en, this message translates to:
  /// **'Dr'**
  String get debitShort;

  /// No description provided for @creditShort.
  ///
  /// In en, this message translates to:
  /// **'Cr'**
  String get creditShort;

  /// No description provided for @debit.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get debit;

  /// No description provided for @credit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get credit;

  /// No description provided for @journalReverse.
  ///
  /// In en, this message translates to:
  /// **'Reverse this entry'**
  String get journalReverse;

  /// No description provided for @journalReverseTitle.
  ///
  /// In en, this message translates to:
  /// **'Reverse entry'**
  String get journalReverseTitle;

  /// No description provided for @journalReverseHelp.
  ///
  /// In en, this message translates to:
  /// **'Posted entries are never edited or deleted. This posts an equal and opposite entry, keeping both on record.'**
  String get journalReverseHelp;

  /// No description provided for @journalReversed.
  ///
  /// In en, this message translates to:
  /// **'Entry reversed'**
  String get journalReversed;

  /// No description provided for @journalDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get journalDescription;

  /// No description provided for @journalControlHelp.
  ///
  /// In en, this message translates to:
  /// **'Member accounts (savings, shares, loans, welfare) aren\'t listed; they change only through their own screens.'**
  String get journalControlHelp;

  /// No description provided for @journalAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get journalAccount;

  /// No description provided for @journalMemo.
  ///
  /// In en, this message translates to:
  /// **'Line note (optional)'**
  String get journalMemo;

  /// No description provided for @journalAddLine.
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get journalAddLine;

  /// No description provided for @journalDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get journalDifference;

  /// No description provided for @journalPost.
  ///
  /// In en, this message translates to:
  /// **'Post entry'**
  String get journalPost;

  /// No description provided for @journalPosted.
  ///
  /// In en, this message translates to:
  /// **'Entry posted'**
  String get journalPosted;

  /// No description provided for @journalNeedsDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a description.'**
  String get journalNeedsDescription;

  /// No description provided for @journalNeedsTwoLines.
  ///
  /// In en, this message translates to:
  /// **'An entry needs at least two lines with an account and amount.'**
  String get journalNeedsTwoLines;

  /// No description provided for @journalOneSidePerLine.
  ///
  /// In en, this message translates to:
  /// **'Each line is either a debit or a credit, not both.'**
  String get journalOneSidePerLine;

  /// No description provided for @journalNotBalanced.
  ///
  /// In en, this message translates to:
  /// **'Debits and credits must be equal.'**
  String get journalNotBalanced;

  /// No description provided for @chartAdd.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get chartAdd;

  /// No description provided for @chartCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get chartCode;

  /// No description provided for @chartName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get chartName;

  /// No description provided for @chartNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Office rent'**
  String get chartNameHint;

  /// No description provided for @chartType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get chartType;

  /// No description provided for @chartAdded.
  ///
  /// In en, this message translates to:
  /// **'Account added'**
  String get chartAdded;

  /// No description provided for @chartControl.
  ///
  /// In en, this message translates to:
  /// **'Member control account'**
  String get chartControl;

  /// No description provided for @typeAsset.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get typeAsset;

  /// No description provided for @typeLiability.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get typeLiability;

  /// No description provided for @typeEquity.
  ///
  /// In en, this message translates to:
  /// **'Equity'**
  String get typeEquity;

  /// No description provided for @typeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get typeIncome;

  /// No description provided for @typeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get typeExpense;

  /// No description provided for @reportsIntro.
  ///
  /// In en, this message translates to:
  /// **'Figures come straight from the ledger. Share any report as a spreadsheet (CSV) for internal, external or Auditor-General audits.'**
  String get reportsIntro;

  /// No description provided for @reportsNone.
  ///
  /// In en, this message translates to:
  /// **'No reports are available for your role.'**
  String get reportsNone;

  /// No description provided for @reportTrialBalance.
  ///
  /// In en, this message translates to:
  /// **'Trial balance'**
  String get reportTrialBalance;

  /// No description provided for @reportTrialBalanceHelp.
  ///
  /// In en, this message translates to:
  /// **'Every account\'s debit or credit balance'**
  String get reportTrialBalanceHelp;

  /// No description provided for @reportBalanceSheet.
  ///
  /// In en, this message translates to:
  /// **'Statement of financial position'**
  String get reportBalanceSheet;

  /// No description provided for @reportBalanceSheetHelp.
  ///
  /// In en, this message translates to:
  /// **'Assets, liabilities and equity'**
  String get reportBalanceSheetHelp;

  /// No description provided for @reportIncomeStatement.
  ///
  /// In en, this message translates to:
  /// **'Income statement'**
  String get reportIncomeStatement;

  /// No description provided for @reportIncomeStatementHelp.
  ///
  /// In en, this message translates to:
  /// **'Income, expenses and surplus for a period'**
  String get reportIncomeStatementHelp;

  /// No description provided for @reportGeneralLedger.
  ///
  /// In en, this message translates to:
  /// **'General ledger'**
  String get reportGeneralLedger;

  /// No description provided for @reportGeneralLedgerHelp.
  ///
  /// In en, this message translates to:
  /// **'One account\'s transactions with running balance'**
  String get reportGeneralLedgerHelp;

  /// No description provided for @reportJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal (day book)'**
  String get reportJournal;

  /// No description provided for @reportJournalHelp.
  ///
  /// In en, this message translates to:
  /// **'Every entry, who posted it, reversals'**
  String get reportJournalHelp;

  /// No description provided for @reportMemberBalances.
  ///
  /// In en, this message translates to:
  /// **'Member balances & reconciliation'**
  String get reportMemberBalances;

  /// No description provided for @reportMemberBalancesHelp.
  ///
  /// In en, this message translates to:
  /// **'Each member\'s balances, checked against control accounts'**
  String get reportMemberBalancesHelp;

  /// No description provided for @reportLoanPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Loan portfolio & arrears'**
  String get reportLoanPortfolio;

  /// No description provided for @reportLoanPortfolioHelp.
  ///
  /// In en, this message translates to:
  /// **'Outstanding loans, ageing and portfolio at risk'**
  String get reportLoanPortfolioHelp;

  /// No description provided for @reportCollections.
  ///
  /// In en, this message translates to:
  /// **'Mobile money collections'**
  String get reportCollections;

  /// No description provided for @reportCollectionsHelp.
  ///
  /// In en, this message translates to:
  /// **'M-Pesa / Selcom payments by outcome'**
  String get reportCollectionsHelp;

  /// No description provided for @reportDistributions.
  ///
  /// In en, this message translates to:
  /// **'Dividend & interest register'**
  String get reportDistributions;

  /// No description provided for @reportDistributionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Declared amounts with withholding tax'**
  String get reportDistributionsHelp;

  /// No description provided for @reportExport.
  ///
  /// In en, this message translates to:
  /// **'Share as spreadsheet'**
  String get reportExport;

  /// No description provided for @reportAsAt.
  ///
  /// In en, this message translates to:
  /// **'As at'**
  String get reportAsAt;

  /// No description provided for @reportFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get reportFrom;

  /// No description provided for @reportTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get reportTo;

  /// No description provided for @reportGeneratedBy.
  ///
  /// In en, this message translates to:
  /// **'Prepared by {name} · amounts in {currency}'**
  String reportGeneratedBy(String name, String currency);

  /// No description provided for @reportNoRows.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this period.'**
  String get reportNoRows;

  /// No description provided for @runPropose.
  ///
  /// In en, this message translates to:
  /// **'Propose run'**
  String get runPropose;

  /// No description provided for @noRuns.
  ///
  /// In en, this message translates to:
  /// **'No dividend or interest runs yet.'**
  String get noRuns;

  /// No description provided for @runMembers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String runMembers(int count);

  /// No description provided for @runPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get runPeriod;

  /// No description provided for @runRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get runRate;

  /// No description provided for @runMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get runMembersLabel;

  /// No description provided for @runProposedBy.
  ///
  /// In en, this message translates to:
  /// **'Proposed by'**
  String get runProposedBy;

  /// No description provided for @runWhtUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Withholding tax rates haven\'t been confirmed by a tax adviser yet.'**
  String get runWhtUnconfirmed;

  /// No description provided for @runApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve run?'**
  String get runApproveTitle;

  /// No description provided for @runApproveBody.
  ///
  /// In en, this message translates to:
  /// **'This posts {amount} net to members\' accounts in the ledger.'**
  String runApproveBody(String amount);

  /// No description provided for @runApproveHelp.
  ///
  /// In en, this message translates to:
  /// **'You can\'t approve a run you proposed.'**
  String get runApproveHelp;

  /// No description provided for @runApproved.
  ///
  /// In en, this message translates to:
  /// **'Run approved and posted'**
  String get runApproved;

  /// No description provided for @runRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject run'**
  String get runRejectTitle;

  /// No description provided for @runRejected.
  ///
  /// In en, this message translates to:
  /// **'Run rejected'**
  String get runRejected;

  /// No description provided for @runPayout.
  ///
  /// In en, this message translates to:
  /// **'Pay out by mobile money'**
  String get runPayout;

  /// No description provided for @runPayoutBody.
  ///
  /// In en, this message translates to:
  /// **'Send {amount} to members\' phones now?'**
  String runPayoutBody(String amount);

  /// No description provided for @runPayoutStarted.
  ///
  /// In en, this message translates to:
  /// **'Payouts started'**
  String get runPayoutStarted;

  /// No description provided for @runRatePercent.
  ///
  /// In en, this message translates to:
  /// **'Rate (%)'**
  String get runRatePercent;

  /// No description provided for @runRatePercentOptional.
  ///
  /// In en, this message translates to:
  /// **'Rate (%) - blank uses the product rate'**
  String get runRatePercentOptional;

  /// No description provided for @runDescription.
  ///
  /// In en, this message translates to:
  /// **'Description, e.g. AGM FY2025 dividend'**
  String get runDescription;

  /// No description provided for @runProposeHelp.
  ///
  /// In en, this message translates to:
  /// **'A different leader must approve before anything is posted.'**
  String get runProposeHelp;

  /// No description provided for @runRateRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the dividend rate.'**
  String get runRateRequired;

  /// No description provided for @runProposed.
  ///
  /// In en, this message translates to:
  /// **'Run proposed, awaiting approval'**
  String get runProposed;

  /// No description provided for @welfareRequiredProduct.
  ///
  /// In en, this message translates to:
  /// **'Choose a savings product.'**
  String get welfareRequiredProduct;

  /// No description provided for @queueAppraise.
  ///
  /// In en, this message translates to:
  /// **'To appraise'**
  String get queueAppraise;

  /// No description provided for @queueDecide.
  ///
  /// In en, this message translates to:
  /// **'To decide'**
  String get queueDecide;

  /// No description provided for @queueDisburse.
  ///
  /// In en, this message translates to:
  /// **'To disburse'**
  String get queueDisburse;

  /// No description provided for @queueActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get queueActive;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No loans here.'**
  String get queueEmpty;

  /// No description provided for @queueDaysOverdue.
  ///
  /// In en, this message translates to:
  /// **'{days} days overdue'**
  String queueDaysOverdue(int days);

  /// No description provided for @queueArrears.
  ///
  /// In en, this message translates to:
  /// **'Arrears'**
  String get queueArrears;

  /// No description provided for @queueAppraisedBy.
  ///
  /// In en, this message translates to:
  /// **'Appraised by'**
  String get queueAppraisedBy;

  /// No description provided for @queueAppraisalNotes.
  ///
  /// In en, this message translates to:
  /// **'Appraisal notes'**
  String get queueAppraisalNotes;

  /// No description provided for @queuePledged.
  ///
  /// In en, this message translates to:
  /// **'Total pledged by guarantors: {amount}'**
  String queuePledged(String amount);

  /// No description provided for @queueAppraiseAction.
  ///
  /// In en, this message translates to:
  /// **'Record appraisal'**
  String get queueAppraiseAction;

  /// No description provided for @queueAppraised.
  ///
  /// In en, this message translates to:
  /// **'Appraisal recorded'**
  String get queueAppraised;

  /// No description provided for @queueApproved.
  ///
  /// In en, this message translates to:
  /// **'Loan approved'**
  String get queueApproved;

  /// No description provided for @queueRejected.
  ///
  /// In en, this message translates to:
  /// **'Loan rejected'**
  String get queueRejected;

  /// No description provided for @queueDisburseAction.
  ///
  /// In en, this message translates to:
  /// **'Disburse loan'**
  String get queueDisburseAction;

  /// No description provided for @queueToSavings.
  ///
  /// In en, this message translates to:
  /// **'To savings'**
  String get queueToSavings;

  /// No description provided for @queueDisbursed.
  ///
  /// In en, this message translates to:
  /// **'Disbursement sent'**
  String get queueDisbursed;

  /// No description provided for @queueAwaitingProvider.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the mobile money provider to confirm.'**
  String get queueAwaitingProvider;

  /// No description provided for @queueRecordRepayment.
  ///
  /// In en, this message translates to:
  /// **'Record repayment'**
  String get queueRecordRepayment;

  /// No description provided for @queueRepaymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Repayment recorded'**
  String get queueRepaymentRecorded;

  /// No description provided for @counterActions.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get counterActions;

  /// No description provided for @counterWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get counterWithdraw;

  /// No description provided for @counterWithdrawConfirm.
  ///
  /// In en, this message translates to:
  /// **'Pay out {amount} to {name}?'**
  String counterWithdrawConfirm(String amount, String name);

  /// No description provided for @counterFromAccount.
  ///
  /// In en, this message translates to:
  /// **'From account'**
  String get counterFromAccount;

  /// No description provided for @counterRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get counterRecorded;

  /// No description provided for @counterVerifyKyc.
  ///
  /// In en, this message translates to:
  /// **'Verify KYC'**
  String get counterVerifyKyc;

  /// No description provided for @counterVerifyKycBody.
  ///
  /// In en, this message translates to:
  /// **'Confirm you\'ve checked this member\'s ID documents.'**
  String get counterVerifyKycBody;

  /// No description provided for @counterPledged.
  ///
  /// In en, this message translates to:
  /// **'Locked as guarantor'**
  String get counterPledged;

  /// No description provided for @counterLimitedView.
  ///
  /// In en, this message translates to:
  /// **'Your role shows member details only.'**
  String get counterLimitedView;

  /// No description provided for @brandTagline.
  ///
  /// In en, this message translates to:
  /// **'Empowerment Group'**
  String get brandTagline;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
