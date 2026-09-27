import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fines_api.dart';
import '../../core/session.dart';
import '../../models/fines.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/inuka_app_bar.dart';
import '../pay_sheet.dart';
import 'fines_screen.dart' show FinesList;

/// A member's own fines: what they were fined for, what they still owe,
/// and paying it by mobile money.
class MyFinesScreen extends StatelessWidget {
  const MyFinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final api = context.read<Session>().api!;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.myFines),
      body: AsyncView<MemberFines>(
        load: api.myFines,
        builder: (context, data, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            MyFinesCard(fines: data, onPaid: reload),
            const SizedBox(height: 12),
            FinesList(fines: data.fines),
          ],
        ),
      ),
    );
  }
}

/// What this member owes in fines - on their Home screen and their fines screen.
class MyFinesCard extends StatelessWidget {
  final MemberFines fines;
  final Future<void> Function()? onPaid;
  final VoidCallback? onTap;
  const MyFinesCard({super.key, required this.fines, this.onPaid, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final owing = fines.outstanding > Decimal.zero;
    return GlassCard(
      onTap: onTap,
      tint: owing
          ? LinearGradient(colors: [
              const Color(0xFFD62C2C).withValues(alpha: 0.92),
              const Color(0xFFF28A1E).withValues(alpha: 0.88),
            ])
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.gavel_rounded, color: owing ? Colors.white : null),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l10n.myFines,
                style: TextStyle(fontWeight: FontWeight.w800, color: owing ? Colors.white : null)),
          ),
          Text(money(context, fines.outstanding),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: owing ? Colors.white : null,
              )),
        ]),
        const SizedBox(height: 4),
        Text(
          owing ? l10n.finesOwedCount(fines.countOutstanding) : l10n.finesNothingOwed,
          style: TextStyle(color: owing ? Colors.white.withValues(alpha: 0.92) : null, fontSize: 13),
        ),
        if (owing && onPaid != null) ...[
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.phone_android_rounded),
            label: Text(l10n.payFines),
            onPressed: () async {
              final paid = await showPaySheet(context,
                  purpose: PayPurpose.fine, initialAmount: fines.outstanding);
              if (paid) await onPaid!();
            },
          ),
        ],
      ]),
    );
  }
}
