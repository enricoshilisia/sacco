import 'package:flutter/material.dart';

import 'common.dart';

/// Prompts for a line of text (reason, notes). Returns null if cancelled.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  bool required = false,
  String? message,
}) async {
  final controller = TextEditingController();
  final l10n = context.l10n;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[Text(message), const SizedBox(height: 12)],
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: label),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: required && controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.done),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

Future<bool> confirm(BuildContext context, {required String title, required String body, required String action}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// A tappable date row that opens the date picker.
class DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.firstDate, this.lastDate});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: Text(formatDate(context, value)),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 366)),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Runs an action with a busy flag and success/error snack bars.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {required String done}) async {
  try {
    await action();
    if (context.mounted) showSnack(context, done);
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(context, e), error: true);
    return false;
  }
}
