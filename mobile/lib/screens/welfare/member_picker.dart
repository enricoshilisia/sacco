import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../models/welfare.dart';
import '../../widgets/common.dart';
import '../../widgets/inuka_app_bar.dart';

/// Full-screen member search (by name, member number or phone) using the
/// welfare-scoped search endpoint. Pops with the chosen [MemberBrief].
Future<MemberBrief?> pickMember(BuildContext context) => Navigator.of(context).push<MemberBrief>(
      MaterialPageRoute(builder: (_) => const _MemberPickerScreen()),
    );

class _MemberPickerScreen extends StatefulWidget {
  const _MemberPickerScreen();

  @override
  State<_MemberPickerScreen> createState() => _MemberPickerScreenState();
}

class _MemberPickerScreenState extends State<_MemberPickerScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<MemberBrief>? _results;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _search(String text) async {
    final id = ++_requestId;
    try {
      final results = await context.read<Session>().api!.searchWelfareMembers(text);
      if (!mounted || id != _requestId) return; // a newer search superseded this one
      setState(() {
        _results = results;
        _error = null;
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: InukaAppBar(
        title: l10n.welfarePickMember,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _query,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(hintText: l10n.searchMemberHint, prefixIcon: const Icon(Icons.search)),
            ),
          ),
        ),
      ),
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: () => _search(_query.text))
          : _results == null
              ? const Center(child: CircularProgressIndicator())
              : _results!.isEmpty
                  ? Center(child: EmptyNote(l10n.noMembersFound))
                  : ListView.separated(
                      itemCount: _results!.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final m = _results![i];
                        return ListTile(
                          leading: CircleAvatar(child: Text(m.fullName.isEmpty ? '?' : m.fullName[0].toUpperCase())),
                          title: Text(m.fullName),
                          subtitle: Text('${m.memberNumber} · ${m.phoneNumber}'),
                          onTap: () => Navigator.pop(context, m),
                        );
                      },
                    ),
    );
  }
}
