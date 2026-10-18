/// Build-time configuration.
///
/// 기본값은 Render에 배포한 백엔드입니다. 로컬 백엔드를 쓰려면
/// `--dart-define=API_URL=http://localhost:8000` 으로 덮어씁니다.
/// 빈 값은 "같은 origin"을 뜻하며, FastAPI가 Flutter 웹 빌드를 직접
/// 서빙할 때(backend/Dockerfile) 사용합니다.
class AppConfig {
  AppConfig._();

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://calender-g6m5.onrender.com',
  );

  static const String apiPrefix = '/api/v1';
  static const String appTitle = 'calender';
  static const String appVersion = '0.1';
}
