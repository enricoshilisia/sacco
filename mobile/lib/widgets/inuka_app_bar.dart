import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/profile_screen.dart';
import '../theme.dart';
import 'glass.dart';
import 'member_avatar.dart';

/// The one top bar used on every signed-in screen, so the app looks the same
/// everywhere: frosted glass, a back button when there's somewhere to go
/// back to, the Inuka West logo and name, the page name, and the person's
/// photo/initials opening their profile.
class InukaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  /// False on the Profile screen itself.
  final bool showProfile;

  const InukaAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.showProfile = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(64 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: (dark ? const Color(0xFF15121A) : Colors.white).withValues(alpha: dark ? 0.35 : 0.4),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: dark ? 0.08 : 0.6))),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      // Same layout on every screen: [back] logo  Inuka West / page  ...  avatar
                      if (canPop) ...[
                        _CircleButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
                        const SizedBox(width: 6),
                      ],
                      const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: InukaLogo(size: 38)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context).appTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: InukaColors.red,
                                  height: 1.1,
                                )),
                            Text(
                              [title, if (subtitle != null && subtitle!.isNotEmpty) subtitle!].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...actions,
                      if (showProfile) const _ProfileAvatar(),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
                ?bottom,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.white.withValues(alpha: dark ? 0.1 : 0.7),
      shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: dark ? 0.15 : 0.9))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, size: 22)),
      ),
    );
  }
}

/// The person's photo (or initials); opens their profile.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context).navProfile,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
        child: const MemberAvatar(size: 40),
      ),
    );
  }
}
