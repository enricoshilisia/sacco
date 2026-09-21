import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme.dart';
import 'common.dart';

/// Shows a temporary password once (new member approved, or a reset), with
/// copy and share buttons so the admin can hand it over. It is not stored
/// anywhere - closing this is the last time it can be seen.
Future<void> showTemporaryPassword(
  BuildContext context, {
  required String name,
  required String phone,
  required String password,
  String? memberNumber,
}) {
  final l10n = context.l10n;
  final message = l10n.tempPasswordShareText(name, phone, password);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        icon: const Icon(Icons.key_rounded, color: InukaColors.orange, size: 36),
        title: Text(l10n.tempPasswordIssued),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text([name, phone, ?memberNumber].join(' · '), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(
              password,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.tempPasswordOnce, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(l10n.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: password));
              if (context.mounted) showSnack(context, l10n.copied);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text(l10n.share),
            onPressed: () => SharePlus.instance.share(ShareParams(text: message)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.done),
          ),
        ],
      );
    },
  );
}
