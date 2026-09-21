import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/sacco.dart';

/// Tokens live in the platform keystore (Android Keystore / iOS Keychain),
/// never in plain preferences - a refresh token is a 7-day credential to
/// a member's money.
class SecureStore {
  static const _storage = FlutterSecureStorage();

  static const _kSacco = 'sacco';
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kBiometric = 'biometric_enabled';
  static const _kLocale = 'locale';

  Future<Sacco?> readSacco() async {
    final raw = await _storage.read(key: _kSacco);
    if (raw == null) return null;
    try {
      return Sacco.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSacco(Sacco? sacco) => sacco == null
      ? _storage.delete(key: _kSacco)
      : _storage.write(key: _kSacco, value: jsonEncode(sacco.toJson()));

  Future<String?> readAccess() => _storage.read(key: _kAccess);
  Future<String?> readRefresh() => _storage.read(key: _kRefresh);

  Future<void> writeTokens(String access, String refresh) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }

  Future<bool> readBiometricEnabled() async => (await _storage.read(key: _kBiometric)) == 'true';
  Future<void> writeBiometricEnabled(bool value) => _storage.write(key: _kBiometric, value: '$value');

  Future<String?> readLocale() => _storage.read(key: _kLocale);
  Future<void> writeLocale(String code) => _storage.write(key: _kLocale, value: code);
}
