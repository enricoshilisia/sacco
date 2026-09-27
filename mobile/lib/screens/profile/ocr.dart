/// Reading the ID number off a photo. On a phone this happens offline with
/// ML Kit; in a browser there is no reader, so the photo is just uploaded
/// and the approver reads it themselves.
library;

export 'ocr_mobile.dart' if (dart.library.js_interop) 'ocr_web.dart';
