import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// In a browser there is no "open in another app": the file is downloaded,
/// and the phone or computer opens it from there.
Future<void> openFile(Uint8List bytes, String fileName, {String? mimeType}) =>
    shareFile(bytes, fileName, mimeType: mimeType);

Future<void> shareFile(Uint8List bytes, String fileName, {String? mimeType, String? subject}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType ?? 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
