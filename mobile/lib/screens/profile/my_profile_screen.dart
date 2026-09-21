import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/leader_api.dart' show isoDate;
import '../../core/profile_api.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../models/profile.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/glass.dart';
import '../../widgets/inuka_app_bar.dart';
import 'document_view.dart';
import 'id_scan.dart';
import 'profile_labels.dart';

/// A member's own details, family register and documents. Identity details
/// and family are locked once approved: changes are sent to the Secretary.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late Future<MyProfile> _profile = _load();

  Future<MyProfile> _load() => context.read<Session>().api!.myProfile();

  Future<void> _reload() async {
    final next = _load();
    setState(() => _profile = next);
    try {
      await next;
      if (mounted) await context.read<Session>().reloadMember();
    } catch (_) {}
  }

  Future<void> _run(Future<Object?> Function() action, String done) async {
    if (await runAction(context, action, done: done)) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.myDetailsTitle),
      body: FutureBuilder<MyProfile>(
        future: _profile,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorRetry(message: errorText(context, snap.error!), onRetry: _reload);
          final p = snap.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Appear(child: _StatusBanner(profile: p, onSubmit: () => _submitForApproval(p))),
                const SizedBox(height: 12),
                Appear(index: 1, child: _personalCard(p)),
                SectionTitle(l10n.idDocuments),
                Appear(index: 2, child: _idCard(p)),
                SectionTitle(
                  l10n.familyRegister,
                  trailing: TextButton.icon(
                    onPressed: () => _editFamily(null),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: Text(l10n.add),
                  ),
                ),
                Text(l10n.familyRegisterHelp, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                if (p.family.isEmpty) EmptyNote(l10n.familyEmpty),
                for (final person in p.family) ...[_familyTile(p, person), const SizedBox(height: 8)],
                SectionTitle(l10n.basicDetails),
                _basicsCard(p.member),
                if (p.requests.isNotEmpty) ...[
                  SectionTitle(l10n.myRequests),
                  for (final r in p.requests.take(10)) _requestTile(r),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Personal details (locked) ---------------------------------------------

  Widget _personalCard(MyProfile p) {
    final l10n = context.l10n;
    final m = p.member;
    final theme = Theme.of(context);
    final rows = <(String, String)>[
      (l10n.fieldFullName, m.fullName),
      (l10n.fieldDateOfBirth, formatDate(context, m.dateOfBirth)),
      (l10n.fieldGender, fieldValue(l10n, 'gender', m.gender)),
      (l10n.fieldIdType, fieldValue(l10n, 'id_type', m.idType)),
      (l10n.idNumber, m.idNumber),
      (l10n.phoneNumber, m.phoneNumber),
      (l10n.fieldMaritalStatus, fieldValue(l10n, 'marital_status', m.maritalStatus)),
    ];
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.personalDetails, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        for (final r in rows) InfoRow(r.$1, r.$2),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: p.hasPendingProfileChange ? null : () => _editPersonal(m),
          icon: const Icon(Icons.edit_note),
          label: Text(p.hasPendingProfileChange ? l10n.changeAwaitingApproval : l10n.requestChange),
        ),
      ]),
    );
  }

  Future<void> _submitForApproval(MyProfile p) async {
    final l10n = context.l10n;
    final ok = await confirm(context, title: l10n.submitForApprovalTitle, body: l10n.submitForApprovalBody, action: l10n.submit);
    if (!ok || !mounted) return;
    await _run(() => context.read<Session>().api!.submitProfileChanges({}), l10n.submittedForApproval);
  }

  Future<void> _editPersonal(Member m) async {
    final changes = await Navigator.of(context).push<(Map<String, dynamic>, String)>(
      MaterialPageRoute(builder: (_) => _PersonalForm(member: m)),
    );
    if (changes == null || !mounted) return;
    await _run(() => context.read<Session>().api!.submitProfileChanges(changes.$1, note: changes.$2),
        context.l10n.changeSentForApproval);
  }

  // --- ID documents -----------------------------------------------------------

  Widget _idCard(MyProfile p) {
    final l10n = context.l10n;
    Widget tile(String type, String label, bool front) {
      final doc = p.documentFor(type);
      return Expanded(
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          onTap: () => doc == null ? _scanId(p, front) : openDocument(context, doc),
          child: Column(children: [
            Icon(doc == null ? Icons.document_scanner_outlined : Icons.badge, size: 30,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (doc == null)
              Text(l10n.tapToScan, style: Theme.of(context).textTheme.bodySmall)
            else if (front && doc.idNumberMatch != null)
              StatusChip(doc.idNumberMatch! ? l10n.idNumberMatches : l10n.idNumberMismatch,
                  tone: doc.idNumberMatch! ? Tone.good : Tone.warn)
            else
              StatusChip(l10n.uploaded, tone: Tone.good),
            if (doc != null)
              TextButton(onPressed: () => _scanId(p, front), child: Text(l10n.replace)),
          ]),
        ),
      );
    }

    return Row(children: [
      tile('ID_FRONT', l10n.idFront, true),
      const SizedBox(width: 12),
      tile('ID_BACK', l10n.idBack, false),
    ]);
  }

  Future<void> _scanId(MyProfile p, bool front) async {
    final l10n = context.l10n;
    final result = await scanIdCard(context, expectedId: p.member.idNumber, front: front);
    if (result == null || !mounted) return;
    if (front) {
      final message = result.readNumber == null
          ? l10n.idNotRead
          : result.matches
              ? l10n.idReadMatches(result.readNumber!)
              : l10n.idReadDifferent(result.readNumber!, p.member.idNumber);
      final go = await confirm(context, title: l10n.idFront, body: message, action: l10n.upload);
      if (!go || !mounted) return;
    }
    await _run(
      () => context.read<Session>().api!.uploadDocument(
            filePath: result.filePath,
            documentType: front ? 'ID_FRONT' : 'ID_BACK',
            ocrIdNumber: result.readNumber ?? '',
          ),
      l10n.documentUploaded,
    );
  }

  // --- Family register ----------------------------------------------------------

  Widget _familyTile(MyProfile p, FamilyPerson person) {
    final l10n = context.l10n;
    final pending = p.pending.where((r) => r.familyMember?.id == person.id).toList();
    final (statusText, tone) = switch (person.status) {
      'APPROVED' => (l10n.statusApproved, Tone.good),
      'PENDING' => (l10n.statusAwaitingApproval, Tone.warn),
      'REJECTED' => (l10n.statusRejected, Tone.bad),
      _ => (person.status, Tone.neutral),
    };
    final certType = person.relationship == 'CHILD' ? 'BIRTH_CERT' : 'ID_FRONT';
    final doc = p.documentFor(certType, familyMemberId: person.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(_relationshipIcon(person.relationship), color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(person.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text([
                relationshipLabel(l10n, person.relationship),
                if (person.age != null) l10n.ageYears(person.age!),
                if (person.isNextOfKin) l10n.fieldNextOfKin,
              ].join(' · '), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                StatusChip(statusText, tone: tone),
                if (pending.isNotEmpty && person.isApproved) StatusChip(l10n.changeAwaitingApproval, tone: Tone.warn),
                if (doc != null) StatusChip(l10n.documentOnFile, tone: Tone.good),
              ]),
            ]),
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _familyAction(action, person, pending),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'doc',
                child: Text(person.relationship == 'CHILD' ? l10n.uploadBirthCert : l10n.uploadIdPhoto),
              ),
              if (person.isApproved && pending.isEmpty) PopupMenuItem(value: 'edit', child: Text(l10n.requestChange)),
              if (person.isApproved && pending.isEmpty) PopupMenuItem(value: 'remove', child: Text(l10n.requestRemoval)),
              if (pending.isNotEmpty) PopupMenuItem(value: 'cancel', child: Text(l10n.cancelRequest)),
            ],
          ),
        ]),
      ),
    );
  }

  IconData _relationshipIcon(String r) => switch (r) {
        'SPOUSE' => Icons.favorite_outline,
        'CHILD' => Icons.child_care,
        'PARENT' || 'PARENT_IN_LAW' => Icons.elderly,
        _ => Icons.people_outline,
      };

  Future<void> _familyAction(String action, FamilyPerson person, List<ChangeRequestItem> pending) async {
    final l10n = context.l10n;
    final api = context.read<Session>().api!;
    switch (action) {
      case 'doc':
        final path = await pickDocumentPhoto(context);
        if (path == null || !mounted) return;
        await _run(
          () => api.uploadDocument(
            filePath: path,
            documentType: person.relationship == 'CHILD' ? 'BIRTH_CERT' : 'ID_FRONT',
            familyMemberId: person.id,
          ),
          l10n.documentUploaded,
        );
      case 'edit':
        await _editFamily(person);
      case 'remove':
        final reason = await askText(context, title: l10n.requestRemoval, label: l10n.welfareReason, required: true,
            message: l10n.removalHelp(person.fullName));
        if (reason == null || !mounted) return;
        await _run(() => api.removeFamilyMember(person.id, note: reason), l10n.changeSentForApproval);
      case 'cancel':
        await _run(() => api.cancelChangeRequest(pending.first.id), l10n.requestCancelled);
    }
  }

  Future<void> _editFamily(FamilyPerson? person) async {
    final result = await Navigator.of(context).push<(Map<String, dynamic>, String)>(
      MaterialPageRoute(builder: (_) => _FamilyForm(person: person)),
    );
    if (result == null || !mounted) return;
    final api = context.read<Session>().api!;
    await _run(
      () => person == null
          ? api.addFamilyMember(result.$1, note: result.$2)
          : api.updateFamilyMember(person.id, result.$1, note: result.$2),
      context.l10n.changeSentForApproval,
    );
  }

  // --- Basic details (free) -----------------------------------------------------

  Widget _basicsCard(Member m) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(l10n.basicDetailsHelp, style: Theme.of(context).textTheme.bodySmall)),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editBasics(m)),
          ]),
          InfoRow(l10n.email, m.email.isEmpty ? '—' : m.email),
          InfoRow(l10n.address, m.physicalAddress.isEmpty ? '—' : m.physicalAddress),
          InfoRow(l10n.fieldOccupation, m.occupation.isEmpty ? '—' : m.occupation),
          InfoRow(l10n.fieldEmployer, m.employer.isEmpty ? '—' : m.employer),
          InfoRow(l10n.fieldCounty, m.county.isEmpty ? '—' : m.county),
        ]),
      ),
    );
  }

  Future<void> _editBasics(Member m) async {
    final l10n = context.l10n;
    final controllers = {
      'email': TextEditingController(text: m.email),
      'physical_address': TextEditingController(text: m.physicalAddress),
      'occupation': TextEditingController(text: m.occupation),
      'employer': TextEditingController(text: m.employer),
      'county': TextEditingController(text: m.county),
    };
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l10n.basicDetails, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final e in controllers.entries) ...[
              TextField(
                controller: e.value,
                keyboardType: e.key == 'email' ? TextInputType.emailAddress : TextInputType.text,
                decoration: InputDecoration(labelText: fieldLabel(l10n, e.key)),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.save)),
          ]),
        ),
      ),
    );
    final values = controllers.map((k, c) => MapEntry(k, c.text.trim()));
    for (final c in controllers.values) {
      c.dispose();
    }
    if (save != true || !mounted) return;
    await _run(() => context.read<Session>().api!.updateMyBasics(values), l10n.saved);
  }

  // --- Requests -------------------------------------------------------------------

  Widget _requestTile(ChangeRequestItem r) {
    final l10n = context.l10n;
    final tone = switch (r.status) { 'APPROVED' => Tone.good, 'REJECTED' => Tone.bad, _ => Tone.warn };
    return Card(
      child: ListTile(
        title: Text([r.targetLabel, if (r.familyMember != null) r.familyMember!.fullName].join(': ')),
        subtitle: Text([
          formatDate(context, r.submittedAt),
          if (r.changes.isNotEmpty && r.target != 'FAMILY_ADD')
            r.changes.keys.map((k) => fieldLabel(l10n, k)).join(', '),
          if (r.decisionNotes.isNotEmpty) '“${r.decisionNotes}”',
        ].join(' · ')),
        trailing: r.isPending
            ? TextButton(
                onPressed: () => _run(() => context.read<Session>().api!.cancelChangeRequest(r.id), l10n.requestCancelled),
                child: Text(l10n.cancel),
              )
            : StatusChip(r.statusLabel, tone: tone),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final MyProfile profile;
  final VoidCallback onSubmit;
  const _StatusBanner({required this.profile, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = profile.member.profileStatus;
    final (icon, title, body, gradient) = switch (status) {
      'APPROVED' => (Icons.verified, l10n.profileVerified, l10n.profileVerifiedHelp,
          const [Color(0xFF2E9E4F), Color(0xFF4CC274)]),
      'PENDING' => (Icons.hourglass_top, l10n.profilePending, l10n.profilePendingHelp,
          const [Color(0xFFF28A1E), Color(0xFFF5B041)]),
      _ => (Icons.assignment_outlined, l10n.profileDraft, l10n.profileDraftHelp,
          const [Color(0xFFE2342B), Color(0xFFF28A1E)]),
    };
    return GlassCard(
      tint: LinearGradient(colors: [gradient[0].withValues(alpha: 0.92), gradient[1].withValues(alpha: 0.88)]),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(body, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13)),
            if (status == 'DRAFT') ...[
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFD62C2C),
                  minimumSize: const Size(0, 40),
                ),
                onPressed: onSubmit,
                child: Text(l10n.submitForApproval),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Form for protected personal details. Returns only changed fields + a note.
class _PersonalForm extends StatefulWidget {
  final Member member;
  const _PersonalForm({required this.member});

  @override
  State<_PersonalForm> createState() => _PersonalFormState();
}

class _PersonalFormState extends State<_PersonalForm> {
  late final _first = TextEditingController(text: widget.member.firstName);
  late final _last = TextEditingController(text: widget.member.lastName);
  late final _other = TextEditingController(text: widget.member.otherNames);
  late final _idNumber = TextEditingController(text: widget.member.idNumber);
  late final _phone = TextEditingController(text: widget.member.phoneNumber);
  final _note = TextEditingController();
  late DateTime? _dob = widget.member.dateOfBirth;
  late String _gender = widget.member.gender;
  late String _idType = widget.member.idType;
  late String _marital = widget.member.maritalStatus;

  @override
  void dispose() {
    for (final c in [_first, _last, _other, _idNumber, _phone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final m = widget.member;
    final changes = <String, dynamic>{
      if (_first.text.trim() != m.firstName) 'first_name': _first.text.trim(),
      if (_last.text.trim() != m.lastName) 'last_name': _last.text.trim(),
      if (_other.text.trim() != m.otherNames) 'other_names': _other.text.trim(),
      if (_idNumber.text.trim() != m.idNumber) 'id_number': _idNumber.text.trim(),
      if (_phone.text.trim() != m.phoneNumber) 'phone_number': _phone.text.trim(),
      if (_gender != m.gender) 'gender': _gender,
      if (_idType != m.idType) 'id_type': _idType,
      if (_marital != m.maritalStatus) 'marital_status': _marital,
      if (_dob != null && (m.dateOfBirth == null || isoDate(_dob!) != isoDate(m.dateOfBirth!))) 'date_of_birth': _dob,
    };
    if (changes.isEmpty) {
      showSnack(context, context.l10n.nothingChanged, error: true);
      return;
    }
    Navigator.pop(context, (changes, _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: InukaAppBar(title: l10n.requestChange),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(l10n.personalChangeHelp, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        TextField(controller: _first, decoration: InputDecoration(labelText: l10n.fieldFirstName)),
        const SizedBox(height: 10),
        TextField(controller: _other, decoration: InputDecoration(labelText: l10n.fieldOtherNames)),
        const SizedBox(height: 10),
        TextField(controller: _last, decoration: InputDecoration(labelText: l10n.fieldLastName)),
        DateField(
          label: l10n.fieldDateOfBirth,
          value: _dob ?? DateTime(1990),
          lastDate: DateTime.now(),
          firstDate: DateTime(1900),
          onChanged: (d) => setState(() => _dob = d),
        ),
        _choice(l10n.fieldGender, _gender, const ['FEMALE', 'MALE', 'OTHER'], (v) => genderLabel(l10n, v),
            (v) => setState(() => _gender = v)),
        const SizedBox(height: 10),
        _choice(l10n.fieldMaritalStatus, _marital, const ['SINGLE', 'MARRIED', 'WIDOWED', 'DIVORCED'],
            (v) => maritalLabel(l10n, v), (v) => setState(() => _marital = v)),
        const SizedBox(height: 10),
        _choice(l10n.fieldIdType, _idType, const ['NATIONAL_ID', 'HUDUMA', 'NIDA', 'PASSPORT'], (v) => idTypeLabel(l10n, v),
            (v) => setState(() => _idType = v)),
        const SizedBox(height: 10),
        TextField(controller: _idNumber, decoration: InputDecoration(labelText: l10n.idNumber)),
        const SizedBox(height: 10),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l10n.phoneNumber)),
        const SizedBox(height: 10),
        TextField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: l10n.changeReason)),
        const SizedBox(height: 20),
        FilledButton(onPressed: _submit, child: Text(l10n.sendForApproval)),
      ]),
    );
  }

  Widget _choice(String label, String value, List<String> options, String Function(String) text, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : null,
        decoration: InputDecoration(labelText: label),
        items: [for (final o in options) DropdownMenuItem(value: o, child: Text(text(o)))],
        onChanged: (v) => v == null ? null : onChanged(v),
      );
}

/// Add or change a family member. Returns (fields, note).
class _FamilyForm extends StatefulWidget {
  final FamilyPerson? person;
  const _FamilyForm({this.person});

  @override
  State<_FamilyForm> createState() => _FamilyFormState();
}

class _FamilyFormState extends State<_FamilyForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.person?.fullName ?? '');
  late final _idNumber = TextEditingController(text: widget.person?.idNumber ?? '');
  late final _birthCert = TextEditingController(text: widget.person?.birthCertificateNumber ?? '');
  late final _phone = TextEditingController(text: widget.person?.phoneNumber ?? '');
  final _note = TextEditingController();
  late String? _relationship = widget.person?.relationship;
  late DateTime? _dob = widget.person?.dateOfBirth;
  late String _gender = widget.person?.gender ?? '';
  late bool _nextOfKin = widget.person?.isNextOfKin ?? false;
  late bool _deceased = widget.person?.isDeceased ?? false;

  @override
  void dispose() {
    for (final c in [_name, _idNumber, _birthCert, _phone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_relationship == 'CHILD' && _dob == null) {
      showSnack(context, l10n.childDobRequired, error: true);
      return;
    }
    final all = <String, dynamic>{
      'relationship': _relationship,
      'full_name': _name.text.trim(),
      'date_of_birth': _dob,
      'gender': _gender,
      'id_number': _idNumber.text.trim(),
      'birth_certificate_number': _birthCert.text.trim(),
      'phone_number': _phone.text.trim(),
      'is_next_of_kin': _nextOfKin,
      'is_deceased': _deceased,
    };
    final p = widget.person;
    if (p == null) {
      all.removeWhere((k, v) => v == null);
      Navigator.pop(context, (all, _note.text.trim()));
      return;
    }
    final original = <String, dynamic>{
      'relationship': p.relationship, 'full_name': p.fullName, 'date_of_birth': p.dateOfBirth, 'gender': p.gender,
      'id_number': p.idNumber, 'birth_certificate_number': p.birthCertificateNumber, 'phone_number': p.phoneNumber,
      'is_next_of_kin': p.isNextOfKin, 'is_deceased': p.isDeceased,
    };
    String key(Object? v) => v is DateTime ? isoDate(v) : '${v ?? ''}';
    final changed = {for (final e in all.entries) if (key(e.value) != key(original[e.key])) e.key: e.value};
    if (changed.isEmpty) {
      showSnack(context, l10n.nothingChanged, error: true);
      return;
    }
    Navigator.pop(context, (changed, _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: InukaAppBar(title: widget.person == null ? l10n.addFamilyMember : l10n.requestChange),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(l10n.familyFormHelp, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _relationship,
            decoration: InputDecoration(labelText: l10n.fieldRelationship),
            items: [for (final r in familyRelationships) DropdownMenuItem(value: r, child: Text(relationshipLabel(l10n, r)))],
            validator: (v) => v == null ? l10n.required : null,
            onChanged: (v) => setState(() => _relationship = v),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.fieldFullName),
            validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
          ),
          DateField(
            label: l10n.fieldDateOfBirth,
            value: _dob ?? DateTime(2010),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
            onChanged: (d) => setState(() => _dob = d),
          ),
          DropdownButtonFormField<String>(
            initialValue: _gender.isEmpty ? null : _gender,
            decoration: InputDecoration(labelText: l10n.fieldGender),
            items: [for (final g in const ['FEMALE', 'MALE', 'OTHER']) DropdownMenuItem(value: g, child: Text(genderLabel(l10n, g)))],
            onChanged: (v) => setState(() => _gender = v ?? ''),
          ),
          const SizedBox(height: 10),
          if (_relationship == 'CHILD')
            TextField(controller: _birthCert, decoration: InputDecoration(labelText: l10n.fieldBirthCert))
          else
            TextField(controller: _idNumber, decoration: InputDecoration(labelText: l10n.idNumber)),
          const SizedBox(height: 10),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l10n.phoneNumber)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.fieldNextOfKin),
            value: _nextOfKin,
            onChanged: (v) => setState(() => _nextOfKin = v),
          ),
          if (widget.person != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.fieldDeceased),
              value: _deceased,
              onChanged: (v) => setState(() => _deceased = v),
            ),
          TextField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: l10n.changeReason)),
          const SizedBox(height: 20),
          FilledButton(onPressed: _submit, child: Text(l10n.sendForApproval)),
        ]),
      ),
    );
  }
}
