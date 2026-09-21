import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import '../models/models.dart';
import '../models/sacco.dart';
import 'api_client.dart';
import 'sacco_api.dart';
import 'secure_store.dart';

enum SessionStage { loading, needsSacco, needsLogin, locked, ready }

/// App-wide auth state: which SACCO, whether we hold tokens, and whether
/// the biometric gate has been passed this launch.
class Session extends ChangeNotifier {
  final SecureStore store;
  final LocalAuthentication _localAuth = LocalAuthentication();

  Session(this.store);

  SessionStage stage = SessionStage.loading;
  Sacco? sacco;
  SaccoApi? api;
  TenantProfile? profile;
  Member? member;
  bool biometricEnabled = false;
  Locale? locale;

  /// Why we're back on the login screen, so it can say so.
  bool sessionExpired = false;
  bool noMemberLinked = false;

  Future<void> bootstrap() async {
    final savedLocale = await store.readLocale();
    if (savedLocale != null) locale = Locale(savedLocale);
    sacco = await store.readSacco();
    biometricEnabled = await store.readBiometricEnabled();
    if (sacco == null) {
      _go(SessionStage.needsSacco);
      return;
    }
    _buildApi();
    final hasRefresh = await store.readRefresh() != null;
    if (!hasRefresh) {
      _go(SessionStage.needsLogin);
    } else if (biometricEnabled) {
      _go(SessionStage.locked);
    } else {
      await _enter();
    }
  }

  void _buildApi() {
    api = SaccoApi(ApiClient(sacco: sacco!, store: store, onSessionExpired: _onExpired));
  }

  void _go(SessionStage next) {
    stage = next;
    notifyListeners();
  }

  Future<void> chooseSacco(Sacco chosen) async {
    sacco = chosen;
    await store.writeSacco(chosen);
    await store.clearTokens();
    locale ??= Locale(chosen.defaultLanguage);
    _buildApi();
    _go(SessionStage.needsLogin);
  }

  Future<void> forgetSacco() async {
    await store.clearTokens();
    await store.writeSacco(null);
    await store.writeBiometricEnabled(false);
    biometricEnabled = false;
    sacco = null;
    api = null;
    profile = null;
    member = null;
    _go(SessionStage.needsSacco);
  }

  Future<void> login(String phone, String password) async {
    final tokens = await api!.login(phone, password);
    await store.writeTokens(tokens.access, tokens.refresh);
    sessionExpired = false;
    noMemberLinked = false;
    await _enter();
  }

  /// Loads who the user is. A login may be a member, staff, or both.
  /// Staff with no member record get only their staff tools; a login
  /// that's neither (no member record, no mobile staff tools) is turned
  /// away with an explanation rather than shown empty screens.
  Future<void> _enter() async {
    try {
      profile = await api!.tenantProfile();
      try {
        member = await api!.myMember();
      } on ApiException catch (e) {
        if (!e.isNotFound) rethrow;
        member = null; // staff-only login
      }
      if (member == null && !profile!.hasStaffTools) {
        await store.clearTokens();
        noMemberLinked = true;
        _go(SessionStage.needsLogin);
        return;
      }
      _go(SessionStage.ready);
    } on ApiException catch (e) {
      if (e.status == 401) return; // _onExpired already moved us to login
      // Offline or server error: keep tokens, show the app shell's retry.
      _go(SessionStage.ready);
    }
  }

  /// Member screens (savings, loans...) show when this login is a member,
  /// or while we couldn't tell (offline - the screens themselves retry).
  bool get isMember => member != null || profile == null;

  bool can(String permission) => profile?.can(permission) ?? false;

  Future<void> reloadMember() async {
    if (member == null) return;
    member = await api!.myMember();
    notifyListeners();
  }

  void _onExpired() {
    store.clearTokens();
    sessionExpired = true;
    profile = null;
    member = null;
    _go(SessionStage.needsLogin);
  }

  Future<void> logout() async {
    await store.clearTokens();
    profile = null;
    member = null;
    _go(SessionStage.needsLogin);
  }

  // --- Biometrics -------------------------------------------------------
  // Local unlock only: the fingerprint/face never leaves the device and
  // the backend never sees it. It gates use of the refresh token already
  // held in the keystore. (The backend's WebAuthn endpoints are for
  // browsers and aren't needed here.)

  Future<bool>? _biometricAvailable;
  Future<bool> biometricAvailable() => _biometricAvailable ??= _checkBiometricAvailable();

  Future<bool> _checkBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics && await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(localizedReason: reason, biometricOnly: false);
    } catch (_) {
      return false;
    }
  }

  Future<void> unlock(String reason) async {
    if (await _authenticate(reason)) await _enter();
  }

  Future<bool> setBiometric(bool enabled, String reason) async {
    if (enabled && !await _authenticate(reason)) return false;
    biometricEnabled = enabled;
    await store.writeBiometricEnabled(enabled);
    notifyListeners();
    return true;
  }

  Future<void> setLocale(Locale value) async {
    locale = value;
    await store.writeLocale(value.languageCode);
    notifyListeners();
  }

  String get currency => sacco?.currency ?? '';
}
