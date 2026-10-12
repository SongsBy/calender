# Frontend

Flutter 앱. Web / iOS / Android / macOS 지원.

## 요구 사항

- Flutter 3.38+
- 백엔드 실행 중 (http://localhost:8000)

## 실행

```bash
flutter pub get

# 웹 (포트 5173은 백엔드 CORS 설정과 맞춰야 함)
flutter run -d chrome --web-port 5173 --dart-define=API_URL=http://localhost:8000

# iOS 시뮬레이터 / Android 에뮬레이터
flutter run --dart-define=API_URL=http://localhost:8000
```

Android 에뮬레이터에서는 `http://10.0.2.2:8000`, 실기기에서는 PC의 LAN IP를 사용합니다.

## 빌드

```bash
# 웹 → 백엔드가 서빙 (API_URL 비우면 같은 origin 사용)
flutter build web --release --dart-define=API_URL= --output ../backend/app/frontend

flutter build apk
flutter build ios
flutter build macos
```

Docker 빌드 시에는 백엔드 Dockerfile이 이 과정을 대신합니다.

## 구조

```
lib/
├── main.dart, app.dart, router.dart, theme.dart
├── core/        설정, API 클라이언트, 저장소, 토스트, 검증
├── models/      API 모델
├── services/    API 호출 (login, users, items)
├── providers/   Riverpod 상태 (auth, theme, items, users)
├── features/    화면 (auth, dashboard, items, admin, settings)
└── shared/      공용 위젯, 앱 셸
```

백엔드 API가 바뀌면 `models/`와 `services/`를 직접 수정합니다.

## 테스트

```bash
flutter analyze
flutter test
```
