import 'dart:convert';

import '../models/sacco.dart';
import 'key_store.dart';

/// Tokens live in the platform keystore (Android Keystore / iOS Keychain),
/// or, in a browser, in that site's own storage - see key_store.dart.
class SecureStore {
  static final _storage = KeyStore();

  static const _kSacco = 'sacco';
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kBiometric = 'biometric_enabled';
  static const _kLocale = 'locale';
  static const _kLocationAsked = 'location_asked';

  Future<Sacco?> readSacco() async {
    final raw = await _storage.read(_kSacco);
    if (raw == null) return null;
    try {
      return Sacco.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSacco(Sacco? sacco) => sacco == null
      ? _storage.delete(_kSacco)
      : _storage.write(_kSacco, jsonEncode(sacco.toJson()));

  Future<String?> readAccess() => _storage.read(_kAccess);
  Future<String?> readRefresh() => _storage.read(_kRefresh);

  Future<void> writeTokens(String access, String refresh) async {
    await _storage.write(_kAccess, access);
    await _storage.write(_kRefresh, refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(_kAccess);
    await _storage.delete(_kRefresh);
  }

  Future<bool> readBiometricEnabled() async => (await _storage.read(_kBiometric)) == 'true';
  Future<void> writeBiometricEnabled(bool value) => _storage.write(_kBiometric, '$value');

  Future<String?> readLocale() => _storage.read(_kLocale);
  Future<void> writeLocale(String code) => _storage.write(_kLocale, code);

  Future<bool> readLocationAsked() async => (await _storage.read(_kLocationAsked)) == 'true';
  Future<void> writeLocationAsked() => _storage.write(_kLocationAsked, 'true');
}
