import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../core/session.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'distributions_screen.dart';
import '../widgets/inuka_app_bar.dart';
import '../widgets/member_avatar.dart';
import 'profile/my_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final member = session.member;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: InukaAppBar(title: l10n.profileTitle, showProfile: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (member != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Tap to change: camera or gallery, any image type.
                    GestureDetector(
                      onTap: session.can('members.edit_own') ? () => changeProfilePhoto(context) : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const MemberAvatar(size: 76),
                          if (session.can('members.edit_own'))
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.photo_camera, size: 14, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.fullName, style: theme.textTheme.titleMedium),
                          Text(l10n.memberNumber(member.memberNumber), style: theme.textTheme.bodySmall),
                          const SizedBox(height: 6),
                          StatusChip(
                            member.isKycVerified ? l10n.kycVerified : l10n.kycPending,
                            tone: member.isKycVerified ? Tone.good : Tone.warn,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(children: [
                  InfoRow(l10n.idNumber, member.idNumber.isEmpty ? '—' : member.idNumber),
                  InfoRow(session.sacco?.name ?? '', formatDate(context, member.dateJoined)),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(l10n.kycLockedHelp, style: theme.textTheme.bodySmall),
            ),
            SectionTitle(
              l10n.contactDetails,
              trailing: session.profile?.can('members.edit_own') == true
                  ? IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editContact(context, member),
                    )
                  : null,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(children: [
                  InfoRow(l10n.phoneNumber, member.phoneNumber.isEmpty ? '—' : member.phoneNumber),
                  InfoRow(l10n.email, member.email.isEmpty ? '—' : member.email),
                  InfoRow(l10n.address, member.physicalAddress.isEmpty ? '—' : member.physicalAddress),
                ]),
              ),
            ),
          ],
          if (member != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.family_restroom),
                title: Text(l10n.myDetailsTitle),
                subtitle: Text(l10n.myDetailsHelp),
                trailing: member.profileApproved
                    ? const Icon(Icons.verified, color: Color(0xFF2E9E4F))
                    : StatusChip(l10n.profileActionNeeded, tone: Tone.warn),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyProfileScreen()));
                  await session.reloadMember();
                },
              ),
            ),
          ],
          if (member == null && session.profile != null) ...[
            Card(
              child: ListTile(
                leading: const MemberAvatar(size: 44),
                title: Text('${session.profile!.firstName} ${session.profile!.lastName}'.trim()),
                subtitle: Text(session.profile!.phoneNumber),
              ),
            ),
          ],
          if ((session.profile?.roles ?? const []).isNotEmpty) ...[
            SectionTitle(l10n.myRoles),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final r in session.profile!.roles) Chip(label: Text(r))],
            ),
          ],
          if (session.isMember) ...[
            SectionTitle(l10n.dividendsTitle),
            Card(
              child: ListTile(
                leading: const Icon(Icons.card_giftcard),
                title: Text(l10n.dividendsTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DistributionsScreen())),
              ),
            ),
          ],
          SectionTitle(l10n.security),
          Card(
            child: Column(
              children: [
                FutureBuilder<bool>(
                  future: session.biometricAvailable(),
                  builder: (context, snapshot) {
                    final available = snapshot.data ?? false;
                    return SwitchListTile(
                      secondary: const Icon(Icons.fingerprint),
                      title: Text(l10n.biometricUnlock),
                      subtitle: available ? null : Text(l10n.biometricUnavailable),
                      value: session.biometricEnabled,
                      onChanged: available ? (v) => session.setBiometric(v, l10n.unlockReason) : null,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: Text(l10n.changePassword),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    useSafeArea: true,
                    builder: (_) => ChangeNotifierProvider.value(value: session, child: const _ChangePasswordSheet()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(l10n.language),
                  trailing: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('EN')),
                      ButtonSegment(value: 'sw', label: Text('SW')),
                    ],
                    selected: {Localizations.localeOf(context).languageCode},
                    onSelectionChanged: (s) => session.setLocale(Locale(s.first)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(children: [
              if (!AppConfig.isSingleSacco)
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: Text(l10n.changeSacco),
                  subtitle: Text(session.sacco?.name ?? ''),
                  onTap: () => session.forgetSacco(),
                ),
              ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text(l10n.logout, style: TextStyle(color: theme.colorScheme.error)),
                onTap: () => session.logout(),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _editContact(BuildContext context, Member member) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<Session>(),
        child: _EditContactSheet(member: member),
      ),
    );
  }
}

class _EditContactSheet extends StatefulWidget {
  final Member member;
  const _EditContactSheet({required this.member});

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  late final _phone = TextEditingController(text: widget.member.phoneNumber);
  late final _email = TextEditingController(text: widget.member.email);
  late final _address = TextEditingController(text: widget.member.physicalAddress);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = context.read<Session>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await session.api!.updateMyContact(phone: _phone.text.trim(), email: _email.text.trim(), address: _address.text.trim());
      await session.reloadMember();
      if (!mounted) return;
      showSnack(context, context.l10n.saved);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.contactDetails, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l10n.phoneNumber)),
          const SizedBox(height: 12),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: l10n.email)),
          const SizedBox(height: 12),
          TextField(controller: _address, maxLines: 2, decoration: InputDecoration(labelText: l10n.address)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.save)),
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().api!.changePassword(_current.text, _next.text);
      if (!mounted) return;
      showSnack(context, context.l10n.passwordChanged);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.changePassword, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.currentPassword),
              validator: (v) => (v ?? '').isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.newPassword),
              validator: (v) => (v ?? '').length < 8 ? l10n.passwordTooShort : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.confirmPassword),
              validator: (v) => v != _next.text ? l10n.passwordMismatch : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.changePassword)),
          ],
        ),
      ),
    );
  }
}
