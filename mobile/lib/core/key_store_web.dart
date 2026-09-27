import 'package:web/web.dart' as web;

/// In a browser there is no keystore. Tokens live in this site's own
/// storage, which only pages from the same SACCO domain can read - the
/// same place every website keeps a session. (The phone apps use the
/// hardware keystore instead.) Encrypted browser storage needs HTTPS, so
/// serve the site over HTTPS before real use.
class KeyStore {
  static const _prefix = 'inuka.';

  web.Storage get _storage => web.window.localStorage;

  Future<String?> read(String key) async => _storage.getItem('$_prefix$key');

  Future<void> write(String key, String value) async => _storage.setItem('$_prefix$key', value);

  Future<void> delete(String key) async => _storage.removeItem('$_prefix$key');
}
