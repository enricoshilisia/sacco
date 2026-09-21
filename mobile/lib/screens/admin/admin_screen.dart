import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_api.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/admin.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/glass.dart';
import '../../widgets/inuka_app_bar.dart';
import 'audit_screen.dart';
import 'positions_screen.dart';
import 'users_screen.dart';

/// Admin & support home: people and their logins, positions, the audit
/// log and membership rules - each shown only if the person's role allows.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final tiles = <(IconData, String, String, Widget Function())>[
      if (session.can('users.view'))
        (Icons.manage_accounts_rounded, l10n.adminUsers, l10n.adminUsersHelp, () => const UsersScreen()),
      if (session.can('accesscontrol.assign_roles'))
        (Icons.workspace_premium_rounded, l10n.adminPositions, l10n.adminPositionsHelp, () => const PositionsScreen()),
      if (session.can('audit.view'))
        (Icons.policy_rounded, l10n.adminAudit, l10n.adminAuditHelp, () => const AuditScreen()),
      if (session.can('audit.view'))
        (Icons.shield_moon_rounded, l10n.adminSecurity, l10n.adminSecurityHelp,
            () => const AuditScreen(securityOnly: true)),
    ];
    return Scaffold(
      appBar: InukaAppBar(title: l10n.adminTitle),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        for (final (i, t) in tiles.indexed) ...[
          Appear(
            index: i,
            child: GlassCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => t.$4())),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(gradient: InukaColors.sunrise, borderRadius: BorderRadius.circular(16)),
                  child: Icon(t.$1, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.$2, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(t.$3, style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (session.can('configuration.edit')) Appear(index: tiles.length, child: const _MembershipRulesCard()),
      ]),
    );
  }
}

/// Registration fee and how many consecutive monthly contributions verify a new member.
class _MembershipRulesCard extends StatefulWidget {
  const _MembershipRulesCard();

  @override
  State<_MembershipRulesCard> createState() => _MembershipRulesCardState();
}

class _MembershipRulesCardState extends State<_MembershipRulesCard> {
  late Future<MembershipRules> _rules = context.read<Session>().api!.membershipRules();

  Future<void> _edit(MembershipRules rules) async {
    final l10n = context.l10n;
    final fee = TextEditingController(text: rules.registrationFee.toString());
    var months = rules.verificationMonths;
    final saved = await showDialog<(Decimal, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.membershipRules),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: fee,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.registrationFee, helperText: l10n.registrationFeeZeroHelp),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(l10n.verificationMonthsLabel)),
              IconButton(onPressed: months > 1 ? () => setState(() => months--) : null, icon: const Icon(Icons.remove)),
              Text('$months', style: Theme.of(context).textTheme.titleMedium),
              IconButton(onPressed: months < 24 ? () => setState(() => months++) : null, icon: const Icon(Icons.add)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () {
                final value = fee.text.trim() == '0' ? Decimal.zero : Money.parseUserInput(fee.text);
                if (value == null) return;
                Navigator.pop(context, (value, months));
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    fee.dispose();
    if (saved == null || !mounted) return;
    final api = context.read<Session>().api!;
    if (await runAction(context, () => api.updateMembershipRules(registrationFee: saved.$1, verificationMonths: saved.$2),
            done: l10n.saved) &&
        mounted) {
      setState(() => _rules = api.membershipRules());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<MembershipRules>(
      future: _rules,
      builder: (context, snap) {
        final rules = snap.data;
        return GlassCard(
          onTap: rules == null ? null : () => _edit(rules),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(gradient: InukaColors.sunrise, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.how_to_reg_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.membershipRules,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  rules == null
                      ? '…'
                      : l10n.membershipRulesSummary(money(context, rules.registrationFee), rules.verificationMonths),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]),
            ),
            const Icon(Icons.edit_outlined),
          ]),
        );
      },
    );
  }
}
