import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android Keystore / iOS Keychain - a refresh token is a 7-day credential
/// to a member's money, so it never sits in plain preferences.
class KeyStore {
  static const _storage = FlutterSecureStorage();

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  Future<void> delete(String key) => _storage.delete(key: key);
}
