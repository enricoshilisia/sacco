library;

/// Where the app keeps its login tokens: the phone's keystore on Android
/// and iOS, the browser's own storage on the web.
export 'key_store_native.dart' if (dart.library.js_interop) 'key_store_web.dart';
