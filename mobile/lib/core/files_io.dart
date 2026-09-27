import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes the file to the phone's temporary area, then tries to open it in
/// whatever app handles it (PDF viewer, Word, gallery); if nothing does,
/// falls back to the share sheet.
Future<void> openFile(Uint8List bytes, String fileName, {String? mimeType}) async {
  final file = await _write(bytes, fileName);
  final result = await OpenFilex.open(file.path, type: mimeType);
  if (result.type != ResultType.done) {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: mimeType)]));
  }
}

/// Hands the file to the share sheet (send by WhatsApp, save to Drive...).
Future<void> shareFile(Uint8List bytes, String fileName, {String? mimeType, String? subject}) async {
  final file = await _write(bytes, fileName);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: mimeType)], subject: subject));
}

Future<File> _write(Uint8List bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
  final file = File('${dir.path}/$safe');
  await file.writeAsBytes(bytes);
  return file;
}
