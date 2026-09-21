import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../widgets/common.dart';

String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Picks the ID number out of text read from an ID card photo. Knows Kenyan
/// national ID numbers (7-9 digits) and Tanzanian NIDA numbers (20 digits,
/// often printed as 19900101-12345-00001-12). If the member already typed
/// their number and it appears on the card, that's the answer.
String? extractIdNumber(String text, {String expected = ''}) {
  final want = digitsOnly(expected);
  final nida = RegExp(r'\b\d{8}[-\s]?\d{5}[-\s]?\d{5}[-\s]?\d{2}\b')
      .allMatches(text)
      .map((m) => digitsOnly(m.group(0)!))
      .toList();
  final short = RegExp(r'(?<!\d)\d{7,9}(?!\d)').allMatches(text).map((m) => m.group(0)!).toList();
  final candidates = [...nida, ...short];

  if (want.isNotEmpty) {
    if (candidates.contains(want)) return want;
    // Numbers printed with odd spacing: accept if the digits appear in order.
    if (digitsOnly(text).contains(want)) return want;
  }
  if (nida.isNotEmpty) return nida.first;
  // Kenyan IDs are usually 8 digits; prefer those over dates/serials.
  final eight = short.where((c) => c.length == 8);
  if (eight.isNotEmpty) return eight.first;
  return short.isEmpty ? null : short.first;
}

class IdScanResult {
  final String filePath;
  final String? readNumber;
  final bool matches;
  const IdScanResult(this.filePath, this.readNumber, this.matches);
}

/// Takes (or chooses) a photo of an ID card and reads the ID number from it
/// on the phone - no internet needed. [expectedId] is the number on record.
Future<IdScanResult?> scanIdCard(BuildContext context, {required String expectedId, required bool front}) async {
  final l10n = context.l10n;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(front ? l10n.idScanFrontTip : l10n.idScanBackTip, textAlign: TextAlign.center),
        ),
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(l10n.photoTake),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(l10n.photoChoose),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (source == null) return null;

  // Documents need detail to stay readable - larger than profile photos.
  final picked = await ImagePicker().pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
  if (picked == null) return null;

  String? read;
  if (front) {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text = await recognizer.processImage(InputImage.fromFilePath(picked.path));
      read = extractIdNumber(text.text, expected: expectedId);
    } catch (_) {
      read = null; // reading failed - the approver still checks the photo
    } finally {
      await recognizer.close();
    }
  }
  final matches = read != null && digitsOnly(expectedId).isNotEmpty && read == digitsOnly(expectedId);
  return IdScanResult(picked.path, read, matches);
}

/// Picks a photo of a certificate (birth, marriage) or other document.
Future<String?> pickDocumentPhoto(BuildContext context) async {
  final l10n = context.l10n;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(l10n.photoTake),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(l10n.photoChoose),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (source == null) return null;
  final picked = await ImagePicker().pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
  return picked?.path;
}
