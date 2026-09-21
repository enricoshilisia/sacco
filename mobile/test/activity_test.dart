import 'package:flutter_test/flutter_test.dart';
import 'package:sacco_mobile/models/governance.dart';
import 'package:sacco_mobile/models/models.dart';
import 'package:sacco_mobile/screens/home_shell.dart';

MyActivity standing(int months, int meetings, {String status = 'ACTIVE'}) => MyActivity.fromJson({
      'status': status,
      'missed_months': months,
      'inactive_after_months': 3,
      'missed_meetings': meetings,
      'inactive_after_meetings': 3,
    });

void main() {
  test('a member one step from a limit is at risk; up to date or dormant members are not', () {
    expect(standing(0, 0).atRisk, isFalse);
    expect(standing(1, 1).atRisk, isFalse);
    expect(standing(2, 0).atRisk, isTrue);
    expect(standing(0, 2).atRisk, isTrue);
    expect(standing(3, 0, status: 'DORMANT').atRisk, isFalse);
    expect(standing(3, 0, status: 'DORMANT').isDormant, isTrue);
  });

  test('the Secretary gets Approvals then Meetings, with Inactive members reachable', () {
    final secretary = TenantProfile.fromJson({
      'permissions': [
        'members.view', 'members.kyc_verify', 'members.approve_changes', 'governance.view',
        'governance.call_meeting', 'governance.take_attendance', 'welfare.view',
      ],
    });
    final menu = buildMenu(isMember: false, profile: secretary);
    expect(menu.bar.take(3), [AppTab.leaderHome, AppTab.approvals, AppTab.meetings]);
    expect([...menu.bar, ...menu.more], contains(AppTab.activity));
  });
}
