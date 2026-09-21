import 'package:flutter_test/flutter_test.dart';
import 'package:sacco_mobile/models/models.dart';
import 'package:sacco_mobile/screens/home_shell.dart';

TenantProfile profile(List<String> permissions) => TenantProfile.fromJson({'permissions': permissions});

// Permissions each seeded role actually holds on the server (see
// backend/accesscontrol/migrations 0003-0014).
const member = ['loans.apply', 'members.edit_own', 'payments.initiate_own_collection', 'governance.vote'];
const treasurer = [
  'accounting.view_ledger', 'accounting.view_trial_balance', 'accounting.post_journal', 'distributions.view',
  'loans.view', 'loans.disburse', 'members.view', 'reports.view', 'reports.export', 'welfare.view',
  'welfare.approve_case',
];
const teller = ['loans.repay', 'members.view', 'savings.deposit', 'savings.view', 'welfare.record_payment'];
const loanOfficer = ['loans.apply', 'loans.appraise', 'loans.view', 'members.view', 'reports.view'];
const chair = [
  'members.view', 'members.approve_admission', 'welfare.view', 'welfare.approve_case', 'governance.call_meeting',
  'governance.take_attendance', 'reports.view', 'accounting.view_ledger', 'loans.view', 'distributions.view',
];
const itAdmin = ['members.view', 'users.view', 'users.reset_password', 'users.manage_access', 'audit.view'];

void main() {
  test('ordinary member: their five money screens, no More', () {
    final menu = buildMenu(isMember: true, profile: profile(member));
    expect(menu.bar, [AppTab.home, AppTab.savings, AppTab.loans, AppTab.welfare, AppTab.profile]);
    expect(menu.more, isEmpty);
  });

  test('treasurer (not a member): leader home, finance first, the rest under More', () {
    final menu = buildMenu(isMember: false, profile: profile(treasurer));
    expect(menu.bar, [AppTab.leaderHome, AppTab.finance, AppTab.loanDesk, AppTab.members, AppTab.more]);
    expect(menu.more, [AppTab.welfareAdmin, AppTab.reports, AppTab.distributions, AppTab.profile]);
  });

  test('treasurer who is also a member: Home, Finance, then their own money', () {
    final menu = buildMenu(isMember: true, profile: profile([...member, ...treasurer]));
    expect(menu.bar, [AppTab.home, AppTab.finance, AppTab.savings, AppTab.loans, AppTab.more]);
    expect(menu.more.first, AppTab.welfare);
    expect(menu.more.last, AppTab.profile);
  });

  test('teller: fits in the bar without More', () {
    final menu = buildMenu(isMember: false, profile: profile(teller));
    expect(menu.bar, [AppTab.leaderHome, AppTab.loanDesk, AppTab.members, AppTab.welfareAdmin, AppTab.profile]);
    expect(menu.more, isEmpty);
  });

  test('loan officer gets the loan desk and reports', () {
    final menu = buildMenu(isMember: false, profile: profile(loanOfficer));
    expect(menu.bar, containsAll([AppTab.loanDesk, AppTab.members, AppTab.reports]));
    expect(menu.bar, isNot(contains(AppTab.finance)));
  });

  test('the bar never has more than five items', () {
    for (final perms in [member, treasurer, teller, loanOfficer, [...member, ...treasurer, ...teller]]) {
      for (final isMember in [true, false]) {
        expect(buildMenu(isMember: isMember, profile: profile(perms)).bar.length, lessThanOrEqualTo(5));
      }
    }
  });

  test('chairperson member: approvals right after home', () {
    final menu = buildMenu(isMember: true, profile: profile(chair));
    expect(menu.bar[1], AppTab.approvals);
  });

  test('IT administrator: admin tools, no money screens', () {
    final menu = buildMenu(isMember: false, profile: profile(itAdmin));
    expect(menu.bar, [AppTab.leaderHome, AppTab.admin, AppTab.members, AppTab.profile]);
    expect(profile(itAdmin).hasStaffTools, isTrue);
  });

  test('temporary password flag is read from the profile', () {
    final p = TenantProfile.fromJson({
      'user': {'id': 'u1', 'must_change_password': true},
      'permissions': <String>[],
    });
    expect(p.mustChangePassword, isTrue);
    expect(p.userId, 'u1');
  });
}
