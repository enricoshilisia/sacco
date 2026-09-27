import 'dart:async';
import 'dart:ui';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../models/fines.dart';
import '../models/leader.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/inuka_app_bar.dart';
import 'fines/my_fines_screen.dart';
import 'leader/tasks_list.dart' show taskScreen;

/// One card in the Home carousel: a headline, a line of detail, and where
/// tapping it goes.
class HomeCard {
  final IconData icon;
  final String title;
  final String detail;
  final String action;
  final Widget Function()? screen;
  const HomeCard({required this.icon, required this.title, required this.detail, required this.action, this.screen});
}

/// The cards that slide across the top of Home: how to pay, what this
/// member owes, and what is waiting for them if they hold a position.
/// Everything sits on the group's own photo, dimmed so the text reads.
class HomeCarousel extends StatefulWidget {
  final MemberFines? fines;
  final List<LeaderTask> tasks;
  const HomeCarousel({super.key, this.fines, this.tasks = const []});

  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel> {
  final _controller = PageController(viewportFraction: 0.93);
  Timer? _timer;
  int _page = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _autoSlide(int count) {
    _timer?.cancel();
    if (count < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage((_page + 1) % count,
          duration: const Duration(milliseconds: 550), curve: Curves.easeInOut);
    });
  }

  List<HomeCard> _cards(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final profile = session.profile;
    final cards = <HomeCard>[];

    if (profile?.hasPaybill ?? false) {
      cards.add(HomeCard(
        icon: Icons.account_balance_wallet_rounded,
        title: l10n.howToPay,
        detail: '${l10n.payBill} ${profile!.paybillNumber} · ${l10n.payAccount} ${profile.paybillAccount}',
        action: l10n.howToPayAction,
        screen: () => const HowToPayScreen(),
      ));
    }

    final fines = widget.fines;
    if (fines != null && fines.outstanding > Decimal.zero) {
      cards.add(HomeCard(
        icon: Icons.gavel_rounded,
        title: l10n.myFines,
        detail: '${money(context, fines.outstanding)} · ${l10n.finesOwedCount(fines.countOutstanding)}',
        action: l10n.payFines,
        screen: () => const MyFinesScreen(),
      ));
    }

    for (final task in widget.tasks) {
      final screen = taskScreen(task.key);
      if (screen == null) continue;
      cards.add(HomeCard(
        icon: task.key == 'fines_outstanding' ? Icons.request_quote_rounded : Icons.task_alt_rounded,
        title: taskLabelFor(context, task.key),
        detail: l10n.waitingOnYou(task.count),
        action: l10n.openNow,
        screen: () => screen,
      ));
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards(context);
    if (cards.isEmpty) return const SizedBox.shrink();
    _autoSlide(cards.length);
    return Column(children: [
      SizedBox(
        height: 168,
        child: PageView.builder(
          controller: _controller,
          onPageChanged: (i) => setState(() => _page = i),
          itemCount: cards.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _CarouselCard(card: cards[i]),
          ),
        ),
      ),
      if (cards.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < cards.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? InukaColors.red : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ]),
        ),
    ]);
  }
}

class _CarouselCard extends StatelessWidget {
  final HomeCard card;
  const _CarouselCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: card.screen == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => card.screen!())),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(fit: StackFit.expand, children: [
          // The group's own photo, blurred and dimmed so it reads as a
          // backdrop rather than competing with the text.
          Image.asset('assets/branding/group.jpg', fit: BoxFit.cover, alignment: Alignment.center),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF7A1010).withValues(alpha: 0.86),
                    const Color(0xFFD62C2C).withValues(alpha: 0.72),
                    const Color(0xFFF28A1E).withValues(alpha: 0.66),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(card.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(card.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ]),
              const Spacer(),
              Text(card.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, height: 1.35)),
              const SizedBox(height: 10),
              Row(children: [
                Text(card.action,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Task names for the carousel (the same wording as "Needs your attention").
String taskLabelFor(BuildContext context, String key) {
  final l10n = context.l10n;
  return switch (key) {
    'loans_to_appraise' => l10n.taskLoansToAppraise,
    'loans_to_decide' => l10n.taskLoansToDecide,
    'loans_to_disburse' => l10n.taskLoansToDisburse,
    'distributions_to_approve' => l10n.taskDistributionsToApprove,
    'welfare_to_approve' => l10n.taskWelfareToApprove,
    'profile_changes_to_approve' => l10n.taskProfileChanges,
    'members_to_archive' => l10n.taskMembersToArchive,
    'applications_to_approve' => l10n.taskApplicationsToApprove,
    'minutes_to_approve' => l10n.taskMinutesToApprove,
    'fines_outstanding' => l10n.taskFinesOutstanding,
    _ => key,
  };
}

/// Everything a member needs in order to pay: the paybill, the steps, and
/// what each payment is for.
class HowToPayScreen extends StatelessWidget {
  const HowToPayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profile = context.watch<Session>().profile;
    final paybill = profile?.paybillNumber ?? '';
    final account = profile?.paybillAccount ?? '';

    Widget step(int number, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: InukaColors.red,
              child: Text('$number',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ]),
        );

    Widget detail(String label, String value) => Card(
          child: ListTile(
            title: Text(label, style: theme.textTheme.bodySmall),
            subtitle: SelectableText(value,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1)),
            trailing: IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: l10n.copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) showSnack(context, l10n.copied);
              },
            ),
          ),
        );

    return Scaffold(
      appBar: InukaAppBar(title: l10n.howToPay),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        detail(l10n.payBill, paybill),
        detail(l10n.payAccount, account),
        if ((profile?.paymentInstructions ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(profile!.paymentInstructions, style: theme.textTheme.bodyMedium),
        ],
        SectionTitle(l10n.howToPaySteps),
        step(1, l10n.payStep1),
        step(2, l10n.payStep2(paybill)),
        step(3, l10n.payStep3(account)),
        step(4, l10n.payStep4),
        step(5, l10n.payStep5),
        SectionTitle(l10n.whatYouPayFor),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.pie_chart_outline),
              title: Text(l10n.monthlyContributions),
              subtitle: Text(l10n.monthlyContributionsHelp),
            ),
            ListTile(
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: Text(l10n.welfareMine),
              subtitle: Text(l10n.welfareBalanceHelp),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(l10n.myFines),
              subtitle: Text(l10n.finesPayHelp),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(l10n.payByHandHelp, style: theme.textTheme.bodySmall),
      ]),
    );
  }
}
