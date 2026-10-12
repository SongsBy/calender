/// Build-time configuration.
///
/// Override with `--dart-define=API_URL=https://api.example.com`.
/// An empty value means "same origin", which is what you want when the
/// Flutter web build is served by FastAPI itself (see README).
class AppConfig {
  AppConfig._();

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String apiPrefix = '/api/v1';
  static const String appTitle = 'FastAPI Template';
}
