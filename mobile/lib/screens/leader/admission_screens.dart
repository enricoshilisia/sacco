import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_api.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../models/admin.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/glass.dart';
import '../../widgets/inuka_app_bar.dart';
import '../../widgets/labels.dart';
import '../../widgets/temp_password.dart';
import '../profile/id_scan.dart';
import '../profile/profile_labels.dart';

(String, Tone) applicationStatus(BuildContext context, String code) {
  final l = context.l10n;
  return switch (code) {
    'PENDING' => (l.statusAwaitingApproval, Tone.warn),
    'APPROVED' => (l.statusApproved, Tone.good),
    'REJECTED' => (l.statusRejected, Tone.bad),
    'CANCELLED' => (l.applicationCancelled, Tone.neutral),
    _ => (code, Tone.neutral),
  };
}

/// New member applications: the Secretary registers them here, the
/// Chairperson approves (Approvals tab). Used both as a screen of its own
/// and embedded in Approvals.
class ApplicationsView extends StatefulWidget {
  final bool embedded;
  const ApplicationsView({super.key, this.embedded = false});

  @override
  State<ApplicationsView> createState() => _ApplicationsViewState();
}

class _ApplicationsViewState extends State<ApplicationsView> {
  String _status = 'PENDING';
  int _version = 0;

  Future<void> _register() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ApplicationFormScreen()),
    );
    if (created == true) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final list = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'PENDING', label: Text(l10n.statusAwaitingApproval)),
            ButtonSegment(value: 'APPROVED', label: Text(l10n.statusApproved)),
            ButtonSegment(value: 'REJECTED', label: Text(l10n.statusRejected)),
          ],
          selected: {_status},
          onSelectionChanged: (s) => setState(() => _status = s.first),
        ),
      ),
      Expanded(
        child: AsyncView<List<MemberApplicationItem>>(
          key: ValueKey('$_status$_version'),
          load: () => session.api!.applications(status: _status),
          builder: (context, items, reload) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (items.isEmpty) EmptyNote(_status == 'PENDING' ? l10n.applicationsEmpty : l10n.reportNoRows),
              for (final (i, a) in items.indexed) ...[
                Appear(
                  index: i,
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(a.fullName.isEmpty ? '?' : a.fullName[0].toUpperCase()),
                      ),
                      title: Text(a.fullName),
                      subtitle: Text([
                        a.field('phone_number'),
                        if (a.memberNumber.isNotEmpty) a.memberNumber,
                        l10n.applicationBy(a.submittedByName, formatDate(context, a.submittedAt)),
                      ].join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ApplicationDetailScreen(application: a)),
                        );
                        setState(() => _version++);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    ]);
    final fab = session.can('members.register')
        ? FloatingActionButton.extended(
            onPressed: _register,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(l10n.registerMember),
          )
        : null;
    if (widget.embedded) {
      return Scaffold(floatingActionButton: fab, body: list);
    }
    return Scaffold(
      appBar: InukaAppBar(title: l10n.applicationsTitle),
      floatingActionButton: fab,
      body: list,
    );
  }
}

/// The Secretary registers a new applicant. Nothing is created until a
/// second person approves; a fee collected now is posted on approval.
class ApplicationFormScreen extends StatefulWidget {
  const ApplicationFormScreen({super.key});

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _other = TextEditingController();
  final _last = TextEditingController();
  final _idNumber = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _occupation = TextEditingController();
  final _employer = TextEditingController();
  final _county = TextEditingController();
  final _notes = TextEditingController();
  final _fee = TextEditingController();
  final _feeRef = TextEditingController();
  DateTime? _dob;
  String _gender = '';
  String _marital = '';
  String _idType = 'NATIONAL_ID';
  String _feeMethod = 'CASH';
  bool _feeCollected = false;
  bool _busy = false;
  MembershipRules? _rules;

  @override
  void initState() {
    super.initState();
    context.read<Session>().api!.membershipRules().then((r) {
      if (!mounted) return;
      setState(() => _rules = r);
      if (r.registrationFee > Decimal.zero) _fee.text = r.registrationFee.toString();
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_first, _other, _last, _idNumber, _phone, _email, _address, _occupation, _employer, _county,
      _notes, _fee, _feeRef]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scanId() async {
    final result = await scanIdCard(context, expectedId: _idNumber.text, front: true);
    if (result?.readNumber != null && mounted) {
      setState(() => _idNumber.text = result!.readNumber!);
      showSnack(context, context.l10n.idScanRead(result!.readNumber!));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final fee = _feeCollected ? Money.parseUserInput(_fee.text) : Decimal.zero;
    if (_feeCollected && (fee == null || fee <= Decimal.zero)) {
      showSnack(context, l10n.amountInvalid, error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => context.read<Session>().api!.submitApplication({
        'first_name': _first.text.trim(),
        'other_names': _other.text.trim(),
        'last_name': _last.text.trim(),
        'date_of_birth': ?_dob,
        'gender': _gender,
        'marital_status': _marital,
        'id_type': _idType,
        'id_number': _idNumber.text.trim(),
        'phone_number': _phone.text.trim(),
        'email': _email.text.trim(),
        'physical_address': _address.text.trim(),
        'occupation': _occupation.text.trim(),
        'employer': _employer.text.trim(),
        'county': _county.text.trim(),
        'notes': _notes.text.trim(),
        'fee_collected': (fee ?? Decimal.zero).toString(),
        'fee_method': _feeCollected ? _feeMethod : '',
        'fee_reference': _feeCollected ? _feeRef.text.trim() : '',
      }),
      done: l10n.applicationSubmitted,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? context.l10n.required : null;

  Widget _choice(String label, String value, List<String> options, String Function(String) text,
          ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : null,
        decoration: InputDecoration(labelText: label),
        items: [for (final o in options) DropdownMenuItem(value: o, child: Text(text(o)))],
        onChanged: (v) => v == null ? null : onChanged(v),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const gap = SizedBox(height: 10);
    return Scaffold(
      appBar: InukaAppBar(title: l10n.registerMember),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          GlassCard(
            child: Text(l10n.registerMemberHelp, style: Theme.of(context).textTheme.bodySmall),
          ),
          SectionTitle(l10n.personalDetails),
          TextFormField(controller: _first, decoration: InputDecoration(labelText: l10n.fieldFirstName), validator: _required),
          gap,
          TextFormField(controller: _other, decoration: InputDecoration(labelText: l10n.fieldOtherNames)),
          gap,
          TextFormField(controller: _last, decoration: InputDecoration(labelText: l10n.fieldLastName), validator: _required),
          DateField(
            label: l10n.fieldDateOfBirth,
            value: _dob ?? DateTime(1990),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
            onChanged: (d) => setState(() => _dob = d),
          ),
          _choice(l10n.fieldGender, _gender, const ['FEMALE', 'MALE', 'OTHER'], (v) => genderLabel(l10n, v),
              (v) => setState(() => _gender = v)),
          gap,
          _choice(l10n.fieldMaritalStatus, _marital, const ['SINGLE', 'MARRIED', 'WIDOWED', 'DIVORCED'],
              (v) => maritalLabel(l10n, v), (v) => setState(() => _marital = v)),
          SectionTitle(l10n.fieldIdType),
          _choice(l10n.fieldIdType, _idType, const ['NATIONAL_ID', 'HUDUMA', 'NIDA', 'PASSPORT'],
              (v) => idTypeLabel(l10n, v), (v) => setState(() => _idType = v)),
          gap,
          TextFormField(
            controller: _idNumber,
            decoration: InputDecoration(
              labelText: l10n.idNumber,
              suffixIcon: IconButton(
                tooltip: l10n.idScan,
                icon: const Icon(Icons.document_scanner_outlined),
                onPressed: _scanId,
              ),
            ),
            validator: _required,
          ),
          SectionTitle(l10n.contactDetails),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l10n.phoneNumber, hintText: '+2547...'),
            validator: _required,
          ),
          gap,
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.email),
          ),
          gap,
          TextFormField(controller: _address, decoration: InputDecoration(labelText: l10n.address)),
          gap,
          TextFormField(controller: _county, decoration: InputDecoration(labelText: l10n.fieldCounty)),
          gap,
          TextFormField(controller: _occupation, decoration: InputDecoration(labelText: l10n.fieldOccupation)),
          gap,
          TextFormField(controller: _employer, decoration: InputDecoration(labelText: l10n.fieldEmployer)),
          SectionTitle(l10n.registrationFee),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _feeCollected,
            onChanged: (v) => setState(() => _feeCollected = v),
            title: Text(l10n.feeCollectedNow),
            subtitle: Text(_rules == null
                ? l10n.feeCollectedHelp
                : '${l10n.registrationFeeIs(money(context, _rules!.registrationFee))}\n${l10n.feeCollectedHelp}'),
          ),
          if (_feeCollected) ...[
            TextFormField(
              controller: _fee,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.amount),
            ),
            gap,
            _choice(l10n.paymentMethodLabel, _feeMethod, const ['CASH', 'BANK', 'MOBILE_MONEY'],
                (v) => paymentMethod(l10n, v), (v) => setState(() => _feeMethod = v)),
            gap,
            TextFormField(controller: _feeRef, decoration: InputDecoration(labelText: l10n.receiptReference)),
          ],
          gap,
          TextFormField(controller: _notes, maxLines: 2, decoration: InputDecoration(labelText: l10n.welfareNotesOptional)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.send_rounded),
            label: Text(l10n.sendForApproval),
          ),
        ]),
      ),
    );
  }
}

class ApplicationDetailScreen extends StatefulWidget {
  final MemberApplicationItem application;
  const ApplicationDetailScreen({super.key, required this.application});

  @override
  State<ApplicationDetailScreen> createState() => _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  bool _busy = false;

  Future<void> _approve() async {
    final l10n = context.l10n;
    final a = widget.application;
    final ok = await confirm(context,
        title: l10n.approveApplication, body: l10n.approveApplicationBody(a.fullName), action: l10n.approve);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await context.read<Session>().api!.approveApplication(a.id);
      if (!mounted) return;
      showSnack(context, l10n.applicationApproved(result.memberNumber));
      if (result.temporaryPassword != null) {
        await showTemporaryPassword(context,
            name: result.fullName,
            phone: result.field('phone_number'),
            password: result.temporaryPassword!,
            memberNumber: result.memberNumber);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final l10n = context.l10n;
    final reason = await askText(context, title: l10n.reject, label: l10n.rejectReasonForMember, required: true);
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    final ok = await runAction(context, () => context.read<Session>().api!.rejectApplication(widget.application.id, reason),
        done: l10n.changeRejected);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _cancel() async {
    final l10n = context.l10n;
    final ok = await confirm(context, title: l10n.cancelApplication, body: l10n.cancelApplicationBody, action: l10n.cancelApplication);
    if (!ok || !mounted) return;
    if (await runAction(context, () => context.read<Session>().api!.cancelApplication(widget.application.id),
            done: l10n.applicationCancelled) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final a = widget.application;
    final (statusText, tone) = applicationStatus(context, a.status);
    final mine = a.submittedBy == session.profile?.userId;
    final pending = a.status == 'PENDING';
    final fields = [
      'first_name', 'other_names', 'last_name', 'date_of_birth', 'gender', 'marital_status', 'id_type', 'id_number',
      'phone_number', 'email', 'physical_address', 'county', 'occupation', 'employer',
    ];
    return Scaffold(
      appBar: InukaAppBar(title: a.fullName, subtitle: l10n.applicationsTitle),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(a.fullName, style: Theme.of(context).textTheme.titleMedium)),
              StatusChip(statusText, tone: tone),
            ]),
            const SizedBox(height: 6),
            Text(l10n.applicationBy(a.submittedByName, formatDate(context, a.submittedAt)),
                style: Theme.of(context).textTheme.bodySmall),
            if (a.decidedByName.isNotEmpty)
              Text(l10n.applicationDecidedBy(a.decidedByName, formatDate(context, a.decidedAt)),
                  style: Theme.of(context).textTheme.bodySmall),
            if (a.decisionNotes.isNotEmpty) ...[const SizedBox(height: 6), Text(a.decisionNotes)],
            if (a.memberNumber.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(l10n.memberNumberIs(a.memberNumber), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
        SectionTitle(l10n.personalDetails),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: [
              for (final f in fields)
                if (a.field(f).isNotEmpty) InfoRow(fieldLabel(l10n, f), fieldValue(l10n, f, a.raw[f])),
            ]),
          ),
        ),
        SectionTitle(l10n.registrationFee),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: a.feeCollected > Decimal.zero
                ? Column(children: [
                    InfoRow(l10n.amount, money(context, a.feeCollected)),
                    InfoRow(l10n.paymentMethodLabel, paymentMethod(l10n, a.feeMethod)),
                    if (a.field('fee_reference').isNotEmpty) InfoRow(l10n.receiptReference, a.field('fee_reference')),
                  ])
                : Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(l10n.feeNotCollected)),
          ),
        ),
        if (a.field('notes').isNotEmpty) ...[SectionTitle(l10n.notes), Text(a.field('notes'))],
        const SizedBox(height: 20),
        if (pending && session.can('members.approve_admission')) ...[
          if (mine)
            Text(l10n.cantApproveOwnApplication, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else
            Row(children: [
              Expanded(
                child: OutlinedButton(onPressed: _busy ? null : _reject, child: Text(l10n.reject)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _busy ? null : _approve, child: Text(l10n.approve)),
              ),
            ]),
          const SizedBox(height: 8),
        ],
        if (pending && session.can('members.register'))
          TextButton(onPressed: _busy ? null : _cancel, child: Text(l10n.cancelApplication)),
      ]),
    );
  }
}
