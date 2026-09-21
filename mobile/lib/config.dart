/// Build-time configuration, supplied with --dart-define. Nothing here is
/// per-SACCO: which SACCO the app talks to is chosen at runtime (the
/// member types their SACCO code; see SaccoApi.lookup), because one app
/// build serves every tenant on the platform.
class AppConfig {
  /// A host that matches no tenant Domain, so django-tenants serves the
  /// public-schema URLconf (backend/config/urls_public.py) - used only to
  /// resolve a SACCO code. 10.0.2.2 is the Android emulator's alias for
  /// the development machine's localhost.
  static const publicApiBaseUrl = String.fromEnvironment(
    'PUBLIC_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Scheme and port used to reach a SACCO's own domain once resolved,
  /// e.g. http + :8000 in development, https + (blank) in production.
  static const tenantScheme = String.fromEnvironment('TENANT_SCHEME', defaultValue: 'http');
  static const tenantPort = String.fromEnvironment('TENANT_PORT', defaultValue: '8000');

  /// Optional: connect to this origin instead of the SACCO's domain, and
  /// send the domain only as the Host header. For local development and
  /// on-prem installs where the tenant domain (e.g. nairobi.localhost)
  /// doesn't resolve from the phone. Leave blank in production.
  static const tenantConnectOverride = String.fromEnvironment('TENANT_CONNECT_OVERRIDE');

  /// Optional: build the app for one SACCO (e.g. Inuka West). The app then
  /// resolves this code itself on first launch, members never see the
  /// "find your SACCO" step, and "Change SACCO" is hidden.
  static const defaultSaccoCode = String.fromEnvironment('DEFAULT_SACCO_CODE');
  static bool get isSingleSacco => defaultSaccoCode.isNotEmpty;
}
