/// Saving a file the person can keep or open, on any platform: phones get
/// the share sheet or the phone's viewer, the browser downloads it.
library;

export 'files_io.dart' if (dart.library.js_interop) 'files_web.dart';
