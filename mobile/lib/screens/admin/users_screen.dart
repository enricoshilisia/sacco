import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_api.dart';
import '../../core/session.dart';
import '../../models/admin.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/glass.dart';
import '../../widgets/inuka_app_bar.dart';
import '../../widgets/temp_password.dart';
import 'audit_screen.dart';
import 'positions_screen.dart';

String lastSeenText(BuildContext context, DateTime? when) {
  final l10n = context.l10n;
  if (when == null) return l10n.neverSeen;
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 2) return l10n.seenJustNow;
  if (diff.inHours < 1) return l10n.seenMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.seenHoursAgo(diff.inHours);
  if (diff.inDays < 30) return l10n.seenDaysAgo(diff.inDays);
  return formatDate(context, when);
}

class _Initials extends StatelessWidget {
  final AdminUser user;
  final double size;
  const _Initials(this.user, {this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: user.loginEnabled ? InukaColors.sunrise : null,
          color: user.loginEnabled ? null : Colors.grey,
        ),
        alignment: Alignment.center,
        child: Text(user.initials,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
      );
}

/// Everyone with a login: search, see roles and last activity, open to
/// reset a password, switch a login off/on, or change positions.
class UsersScreen extends StatefulWidget {
  /// When set, tapping a person returns them instead of opening details.
  final bool pick;
  const UsersScreen({super.key, this.pick = false});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  bool _disabledOnly = false;
  late Future<List<AdminUser>> _users = _load();

  Future<List<AdminUser>> _load() =>
      context.read<Session>().api!.users(search: _query.text.trim(), disabledOnly: _disabledOnly);

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: InukaAppBar(
        title: widget.pick ? l10n.pickPerson : l10n.adminUsers,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchPeopleHint),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _users = _load()));
              },
            ),
          ),
        ),
      ),
      body: Column(children: [
        if (!widget.pick)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              FilterChip(
                label: Text(l10n.disabledLogins),
                selected: _disabledOnly,
                onSelected: (v) => setState(() {
                  _disabledOnly = v;
                  _users = _load();
                }),
              ),
            ]),
          ),
        Expanded(
          child: FutureBuilder<List<AdminUser>>(
            future: _users,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) {
                return ErrorRetry(message: errorText(context, snap.error!), onRetry: () => setState(() => _users = _load()));
              }
              final users = snap.data!;
              if (users.isEmpty) return Center(child: EmptyNote(l10n.noPeopleFound));
              return RefreshIndicator(
                onRefresh: () async => setState(() => _users = _load()),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return Appear(
                      index: i,
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () async {
                          if (widget.pick) {
                            Navigator.pop(context, u);
                            return;
                          }
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserDetailScreen(userId: u.id)));
                          if (mounted) setState(() => _users = _load());
                        },
                        child: Row(children: [
                          _Initials(u),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(u.name.isEmpty ? u.phoneNumber : u.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text([u.phoneNumber, if (u.memberNumber.isNotEmpty) u.memberNumber].join(' · '),
                                  style: Theme.of(context).textTheme.bodySmall),
                              if (u.positions.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(spacing: 4, runSpacing: 4, children: [
                                  for (final p in u.positions) _MiniChip(p),
                                ]),
                              ],
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            if (!u.loginEnabled) StatusChip(l10n.loginDisabled, tone: Tone.bad),
                            if (u.loginEnabled && u.memberVerified == false) StatusChip(l10n.probation, tone: Tone.warn),
                            const SizedBox(height: 4),
                            Text(lastSeenText(context, u.lastSeen), style: Theme.of(context).textTheme.labelSmall),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text;
  const _MiniChip(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: InukaColors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: InukaColors.red)),
      );
}

/// One person: who they are, positions, where they've signed in from,
/// recent activity, and the support actions.
class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _view = GlobalKey<AsyncViewState<(AdminUser, List<({String membershipId, String roleName, String jobTitle, bool automatic})>)>>();

  Future<(AdminUser, List<({String membershipId, String roleName, String jobTitle, bool automatic})>)> _load() async {
    final api = context.read<Session>().api!;
    final user = await api.user(widget.userId);
    final positions = await api.userPositions(widget.userId);
    return (user, positions);
  }

  Future<void> _reset(AdminUser u) async {
    final l10n = context.l10n;
    final ok = await confirm(context, title: l10n.resetPassword, body: l10n.resetPasswordBody(u.name), action: l10n.resetPassword);
    if (!ok || !mounted) return;
    try {
      final temporary = await context.read<Session>().api!.resetPassword(u.id);
      if (!mounted) return;
      await showTemporaryPassword(context, name: u.name, phone: u.phoneNumber, password: temporary,
          memberNumber: u.memberNumber.isEmpty ? null : u.memberNumber);
      _view.currentState?.reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e), error: true);
    }
  }

  Future<void> _toggleLogin(AdminUser u) async {
    final l10n = context.l10n;
    final enable = !u.loginEnabled;
    final ok = await confirm(context,
        title: enable ? l10n.enableLogin : l10n.disableLogin,
        body: enable ? l10n.enableLoginBody(u.name) : l10n.disableLoginBody(u.name),
        action: enable ? l10n.enableLogin : l10n.disableLogin);
    if (!ok || !mounted) return;
    if (await runAction(context, () => context.read<Session>().api!.setLoginEnabled(u.id, enable),
        done: enable ? l10n.loginEnabled : l10n.loginDisabled)) {
      _view.currentState?.reload();
    }
  }

  Future<void> _givePosition(AdminUser u) async {
    final l10n = context.l10n;
    final api = context.read<Session>().api!;
    final positions = await api.positions();
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Position>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView(controller: controller, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(l10n.givePositionTo(u.name), style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final p in positions)
            if (!u.roles.contains(p.name))
              ListTile(
                enabled: !p.isFull,
                leading: Icon(p.isPosition ? Icons.workspace_premium_outlined : Icons.badge_outlined),
                title: Text(p.name),
                subtitle: Text(p.isFull ? l10n.positionFull : holdersText(context, p)),
                onTap: () => Navigator.pop(context, p),
              ),
        ]),
      ),
    );
    if (chosen == null || !mounted) return;
    if (await runAction(context, () => api.assignPosition(chosen.id, userId: u.id),
        done: l10n.positionAssigned(u.name, chosen.name))) {
      _view.currentState?.reload();
    }
  }

  Future<void> _remove(AdminUser u, String membershipId, String roleName) async {
    final l10n = context.l10n;
    final ok = await confirm(context,
        title: l10n.removeFromPosition, body: l10n.removeFromPositionBody(u.name, roleName), action: l10n.remove);
    if (!ok || !mounted) return;
    if (await runAction(context, () => context.read<Session>().api!.removeFromPosition(membershipId),
        done: l10n.positionRemoved)) {
      _view.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: InukaAppBar(title: l10n.adminUsers),
      body: AsyncView<(AdminUser, List<({String membershipId, String roleName, String jobTitle, bool automatic})>)>(
        key: _view,
        load: _load,
        builder: (context, data, reload) {
          final (u, positions) = data;
          final isMe = u.id == session.profile?.userId;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            GlassCard(
              child: Row(children: [
                _Initials(u, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(u.phoneNumber),
                    if (u.memberNumber.isNotEmpty) Text(u.memberNumber, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      StatusChip(u.loginEnabled ? l10n.loginActive : l10n.loginDisabled,
                          tone: u.loginEnabled ? Tone.good : Tone.bad),
                      if (u.memberVerified == false) StatusChip(l10n.probation, tone: Tone.warn),
                      if (u.mustChangePassword) StatusChip(l10n.temporaryPasswordPending, tone: Tone.warn),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(children: [
                  InfoRow(l10n.lastSignIn, u.lastLogin == null ? l10n.neverSeen : lastSeenText(context, u.lastLogin)),
                  InfoRow(l10n.lastActive, lastSeenText(context, u.lastSeen)),
                  if (u.email.isNotEmpty) InfoRow(l10n.email, u.email),
                ]),
              ),
            ),
            if (!isMe) ...[
              SectionTitle(l10n.supportActions),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (session.can('users.reset_password'))
                  ActionChip(
                    avatar: const Icon(Icons.key_rounded, size: 18),
                    label: Text(l10n.resetPassword),
                    onPressed: () => _reset(u),
                  ),
                if (session.can('users.manage_access'))
                  ActionChip(
                    avatar: Icon(u.loginEnabled ? Icons.block_rounded : Icons.lock_open_rounded, size: 18),
                    label: Text(u.loginEnabled ? l10n.disableLogin : l10n.enableLogin),
                    onPressed: () => _toggleLogin(u),
                  ),
                if (session.can('audit.view'))
                  ActionChip(
                    avatar: const Icon(Icons.policy_outlined, size: 18),
                    label: Text(l10n.viewActivity),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AuditScreen(userId: u.id, userName: u.name))),
                  ),
              ]),
            ],
            SectionTitle(l10n.positionsHeld),
            Card(
              child: Column(children: [
                for (final p in positions)
                  ListTile(
                    leading: Icon(p.automatic ? Icons.person_outline : Icons.workspace_premium_outlined),
                    title: Text(p.roleName),
                    subtitle: p.jobTitle.isEmpty ? null : Text(p.jobTitle),
                    trailing: !p.automatic && session.can('accesscontrol.assign_roles')
                        ? IconButton(
                            tooltip: l10n.removeFromPosition,
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _remove(u, p.membershipId, p.roleName),
                          )
                        : null,
                  ),
                if (session.can('accesscontrol.assign_roles'))
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text(l10n.givePosition),
                    onTap: () => _givePosition(u),
                  ),
              ]),
            ),
            if (u.recentDevices.isNotEmpty) ...[
              SectionTitle(l10n.devicesAndPlaces),
              Card(
                child: Column(children: [
                  for (final d in u.recentDevices)
                    ListTile(
                      leading: Icon(d.device.contains('web') ? Icons.computer_rounded : Icons.phone_android_rounded),
                      title: Text(d.device),
                      subtitle: Text([if (d.location.isNotEmpty) d.location, if (d.ip.isNotEmpty) d.ip].join(' · ')),
                    ),
                ]),
              ),
            ],
            if (u.recentActivity.isNotEmpty) ...[
              SectionTitle(l10n.recentActivity),
              Card(
                child: Column(children: [
                  for (final a in u.recentActivity)
                    ListTile(
                      dense: true,
                      title: Text(a.summary),
                      subtitle: Text([lastSeenText(context, a.at), if (a.location.isNotEmpty) a.location].join(' · ')),
                    ),
                ]),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
