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
import 'users_screen.dart';

String holdersText(BuildContext context, Position p) {
  final l10n = context.l10n;
  return p.maxHolders == null
      ? l10n.holdersCount(p.holders.length)
      : l10n.holdersOfMax(p.holders.length, p.maxHolders!);
}

/// Offices and roles, who holds each, and room left. Assign someone,
/// remove them, or create a new position (e.g. a committee seat).
class PositionsScreen extends StatefulWidget {
  const PositionsScreen({super.key});

  @override
  State<PositionsScreen> createState() => _PositionsScreenState();
}

class _PositionsScreenState extends State<PositionsScreen> {
  final _view = GlobalKey<AsyncViewState<List<Position>>>();

  Future<void> _assign(Position p) async {
    final l10n = context.l10n;
    final user = await Navigator.of(context).push<AdminUser>(
      MaterialPageRoute(builder: (_) => const UsersScreen(pick: true)),
    );
    if (user == null || !mounted) return;
    final title = await askText(context, title: l10n.jobTitleOptional, label: l10n.jobTitleHint);
    if (title == null || !mounted) return;
    if (await runAction(context, () => context.read<Session>().api!.assignPosition(p.id, userId: user.id, jobTitle: title),
        done: l10n.positionAssigned(user.name, p.name))) {
      _view.currentState?.reload();
    }
  }

  Future<void> _remove(Position p, PositionHolder h) async {
    final l10n = context.l10n;
    final ok = await confirm(context,
        title: l10n.removeFromPosition, body: l10n.removeFromPositionBody(h.name, p.name), action: l10n.remove);
    if (!ok || !mounted) return;
    if (await runAction(context, () => context.read<Session>().api!.removeFromPosition(h.membershipId),
        done: l10n.positionRemoved)) {
      _view.currentState?.reload();
    }
  }

  Future<void> _create(List<Position> all) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _NewPositionScreen(existing: all)),
    );
    if (created == true) _view.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final api = context.read<Session>().api!;
    return AsyncView<List<Position>>(
      key: _view,
      load: api.positions,
      builder: (context, positions, reload) {
        final offices = positions.where((p) => p.isPosition).toList();
        final staff = positions.where((p) => !p.isPosition).toList();
        return Scaffold(
          appBar: InukaAppBar(title: l10n.adminPositions),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _create(positions),
            icon: const Icon(Icons.add),
            label: Text(l10n.newPosition),
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
            Text(l10n.positionsHelp, style: Theme.of(context).textTheme.bodySmall),
            SectionTitle(l10n.officesAndCommittees),
            for (final (i, p) in offices.indexed) ...[
              Appear(index: i, child: _PositionCard(position: p, onAssign: () => _assign(p), onRemove: (h) => _remove(p, h))),
              const SizedBox(height: 10),
            ],
            SectionTitle(l10n.staffRoles),
            for (final (i, p) in staff.indexed) ...[
              Appear(
                index: offices.length + i,
                child: _PositionCard(position: p, onAssign: () => _assign(p), onRemove: (h) => _remove(p, h)),
              ),
              const SizedBox(height: 10),
            ],
          ]),
        );
      },
    );
  }
}

class _PositionCard extends StatelessWidget {
  final Position position;
  final VoidCallback onAssign;
  final ValueChanged<PositionHolder> onRemove;
  const _PositionCard({required this.position, required this.onAssign, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final p = position;
    final vacancies = p.maxHolders == null ? 0 : (p.maxHolders! - p.holders.length).clamp(0, 99);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: p.assistantOf == null ? InukaColors.sunrise : null,
              color: p.assistantOf == null ? null : InukaColors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              p.assistantOf == null ? Icons.workspace_premium_rounded : Icons.support_agent_rounded,
              color: p.assistantOf == null ? Colors.white : InukaColors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                [
                  if (p.assistantOfName.isNotEmpty) l10n.assistantTo(p.assistantOfName),
                  holdersText(context, p),
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ]),
          ),
          if (!p.isFull)
            IconButton.filledTonal(
              tooltip: l10n.assignPerson,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: onAssign,
            ),
        ]),
        if (p.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(p.description, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final h in p.holders)
            InputChip(
              avatar: CircleAvatar(
                backgroundColor: InukaColors.orange,
                child: Text(h.name.isEmpty ? '?' : h.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              label: Text(h.jobTitle.isEmpty ? h.name : '${h.name} · ${h.jobTitle}'),
              onDeleted: () => onRemove(h),
              deleteButtonTooltipMessage: l10n.removeFromPosition,
            ),
          for (var i = 0; i < vacancies; i++)
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(l10n.vacant),
              onPressed: onAssign,
            ),
        ]),
      ]),
    );
  }
}

class _NewPositionScreen extends StatefulWidget {
  final List<Position> existing;
  const _NewPositionScreen({required this.existing});

  @override
  State<_NewPositionScreen> createState() => _NewPositionScreenState();
}

class _NewPositionScreenState extends State<_NewPositionScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  int? _maxHolders = 1;
  String? _copyFrom;
  String? _assistantOf;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_name.text.trim().isEmpty) {
      showSnack(context, l10n.required, error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => context.read<Session>().api!.createPosition(
            name: _name.text.trim(),
            description: _description.text.trim(),
            maxHolders: _maxHolders,
            copyFrom: _assistantOf == null ? _copyFrom : null,
            assistantOf: _assistantOf,
          ),
      done: l10n.positionCreated,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sources = widget.existing.where((p) => p.name != 'SuperAdmin').toList();
    return Scaffold(
      appBar: InukaAppBar(title: l10n.newPosition),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(child: Text(l10n.newPositionHelp, style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: InputDecoration(labelText: l10n.positionName, hintText: l10n.positionNameHint)),
        const SizedBox(height: 10),
        TextField(controller: _description, maxLines: 2, decoration: InputDecoration(labelText: l10n.positionDuties)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          initialValue: _assistantOf,
          decoration: InputDecoration(labelText: l10n.assistantOfLabel, helperText: l10n.assistantOfHelp),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.notAnAssistant)),
            for (final p in sources.where((p) => p.isPosition && p.assistantOf == null))
              DropdownMenuItem(value: p.id, child: Text(p.name)),
          ],
          onChanged: (v) => setState(() => _assistantOf = v),
        ),
        if (_assistantOf == null) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _copyFrom,
            decoration: InputDecoration(labelText: l10n.copyPermissionsFrom, helperText: l10n.copyPermissionsHelp),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.noPermissionsYet)),
              for (final p in sources) DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _copyFrom = v),
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text(l10n.maxHoldersLabel)),
          IconButton(
            onPressed: (_maxHolders ?? 0) > 1 ? () => setState(() => _maxHolders = _maxHolders! - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          Text(_maxHolders == null ? '∞' : '$_maxHolders', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            onPressed: _maxHolders == null ? null : () => setState(() => _maxHolders = _maxHolders! + 1),
            icon: const Icon(Icons.add),
          ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.noLimit),
          value: _maxHolders == null,
          onChanged: (v) => setState(() => _maxHolders = v ? null : 1),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.createPosition)),
      ]),
    );
  }
}
