import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../widgets/common.dart';
import '../../widgets/inuka_app_bar.dart';

/// Full-screen, zoomable view of a KYC document photo.
void openDocument(BuildContext context, MemberDocumentItem doc) {
  if (doc.isPdf) {
    showSnack(context, context.l10n.pdfOnFile);
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => _DocumentScreen(doc: doc)));
}

class _DocumentScreen extends StatelessWidget {
  final MemberDocumentItem doc;
  const _DocumentScreen({required this.doc});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: InukaAppBar(
        title: doc.documentTypeLabel,
        subtitle: [
          if (doc.familyMemberName.isNotEmpty) doc.familyMemberName,
          if (doc.ocrIdNumber.isNotEmpty) l10n.idNumberRead(doc.ocrIdNumber),
        ].join(' · '),
      ),
      body: InteractiveViewer(
        maxScale: 6,
        child: Center(
          child: Image.network(
            doc.fileUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, _, _) => EmptyNote(l10n.documentLoadFailed),
          ),
        ),
      ),
    );
  }
}

/// Small thumbnail that opens the full document.
class DocumentThumb extends StatelessWidget {
  final MemberDocumentItem doc;
  const DocumentThumb({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: () => openDocument(context, doc),
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 120,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 80,
              width: 120,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: doc.isPdf
                  ? const Icon(Icons.picture_as_pdf, size: 36)
                  : Image.network(doc.fileUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported)),
            ),
          ),
          const SizedBox(height: 4),
          Text(doc.documentTypeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          if (doc.idNumberMatch != null)
            StatusChip(doc.idNumberMatch! ? l10n.idNumberMatches : l10n.idNumberMismatch,
                tone: doc.idNumberMatch! ? Tone.good : Tone.warn),
        ]),
      ),
    );
  }
}
