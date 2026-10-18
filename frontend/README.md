# Frontend

Flutter 앱. Web / iOS / Android / macOS 지원.

## 요구 사항

- Flutter 3.38+
- 백엔드: 기본값은 Render에 배포된 `https://calender-g6m5.onrender.com`
  (`lib/core/config.dart`). 무료 인스턴스라 잠들어 있으면 첫 요청이 30초 이상 걸립니다.

## 실행

```bash
flutter pub get

# iOS 시뮬레이터 / Android 에뮬레이터 / macOS → Render 백엔드 (옵션 없음)
flutter run

# 로컬 백엔드(http://localhost:8000)를 쓸 때만 주소를 덮어씀
flutter run --dart-define=API_URL=http://localhost:8000

# 웹 (포트 5173은 백엔드 CORS 설정 FRONTEND_HOST와 맞춰야 함)
flutter run -d chrome --web-port 5173 --dart-define=API_URL=http://localhost:8000
```

로컬 백엔드를 Android 에뮬레이터에서 쓸 때는 `http://10.0.2.2:8000`, 실기기에서는 PC의 LAN IP를 사용합니다.
브라우저에서 Render 주소를 직접 열면 백엔드가 서빙하는 웹 빌드가 같은 origin으로 동작합니다.

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
├── main.dart, app.dart, router.dart
├── theme.dart   디자인 토큰 (색·타이포·간격·모서리) + ThemeData
├── core/        설정, API 클라이언트, 저장소, 토스트, 한국어 날짜 포맷
├── models/      API 모델
├── services/    API 호출 (login, users, calendars, events, device calendar)
├── providers/   Riverpod 상태 (auth, calendars, events)
├── features/    화면 (auth, home, calendars, events)
└── shared/      디자인 시스템 위젯(ds.dart), 아이콘·일러스트(SVG), 당겨서 갱신
```

UI는 Claude Design으로 만든 "우리의 하루" 시안(앱 이름은 CC)(디자인 토큰·컴포넌트 보드)을
그대로 옮긴 것입니다. 글꼴은 `assets/fonts/PretendardVariable.ttf`
(SIL OFL) 하나이며, 모든 색·크기 값은 `lib/theme.dart`에 모여 있습니다.

백엔드 API가 바뀌면 `models/`와 `services/`를 직접 수정합니다.

## 테스트

```bash
flutter analyze
flutter test                 # 단위·위젯 테스트 (백엔드 불필요)

# 실제 백엔드를 상대로 API 레이어 검증 (백엔드가 떠 있어야 함)
flutter test test/e2e --dart-define=RUN_E2E=true --dart-define=API_URL=http://localhost:8000
```


## 공유 일정 UI (2026-10-18)

메뉴 **공유 캘린더 → 일정 보기**에서 월별 달력을 연다. 날짜를 선택하면 해당 날짜에 겹치는 일정을 표시한다. 파란색/주황색 점과 작성자 이름으로 두 구성원을 구분한다.

- **일정 등록**: 제목·설명, 종일 여부, 시작/종료 날짜와 시간 입력. 종일 일정의 마지막 날짜는 화면에서는 포함, API에서는 다음 날을 제외 종료일로 전송한다.
- **일정 선택**: 내 일정은 편집/삭제, 상대방 일정은 읽기 전용 상세. 삭제 전 확인한다. 서버 권한 검사도 그대로 적용된다.
- 시간은 기기 시간대와 무관하게 캘린더 IANA 시간대를 사용한다. `timezone` 패키지로 UTC 변환과 날짜 겹침을 계산한다. DST로 존재하지 않는 시간은 입력을 거절한다. 바꾸지 않은 기존 시각은 초 단위와 UTC 값을 보존한다.
- 월별 API의 페이지를 모두 읽은 뒤 날짜별 표시를 계산한다. 실패를 빈 일정으로 표시하지 않고 재시도 버튼을 보여준다.
- 생성·수정·삭제 후 재조회한다. 앱 복귀와 새로고침도 지원한다. 실시간 푸시 구독은 아직 없다.
- `models/event.dart`: 일정·입력 데이터와 날짜 계산. `services/events_service.dart`: API 호출. `providers/events_provider.dart`: 계정/캘린더/월별 조회 상태. `features/events/`: 달력과 편집 창.
- `AppShell`은 라우트 Navigator에 화면 높이를 제공하고 각 페이지의 `AppPage`가 스크롤을 담당한다. Navigator 전체를 스크롤 안에 넣었을 때 생기던 Android 화면 넘침을 수정했다.

검증: Flutter 테스트 32개 및 analyze 통과. 격리 API를 대상으로 A 등록 → B 조회 → B 수정/삭제 거절 → 종일 전환 → 삭제를 실제 Flutter 서비스로 확인했다. 웹 빌드와 Android 에뮬레이터 빌드·설치·실행을 확인했다. 브라우저는 테스트 데이터로 실제 달력 위젯을 렌더링해 시각 확인했으며 전체 로그인 UI 자동 조작은 완료하지 못했다. 실제 두 휴대폰 검증과 Android 원본 일정 가져오기는 남아 있다.

### Android 기기 일정 가져오기

공유 캘린더의 **기기 일정 가져오기**에서 읽기 권한 → 캘린더/기간 → 일정 선택 → 공유 확인 순서로 이용합니다. 원본은 수정하지 않으며 자동 동기화되지 않습니다. 동일 기기·계정·대상 캘린더에서 같은 회차를 다시 가져오면 건너뜁니다. 네이티브 코드가 추가되어 APK 재빌드가 필요합니다.

상세 설계와 검증 절차: [native-calendar-import.md](../backend/docs/native-calendar-import.md).

### 캘린더 나가기·삭제

캘린더 목록 카드에서 만든 사람은 **캘린더 삭제**, 참여자는 **캘린더 나가기**를 사용할 수 있습니다. 나가면 본인의 공유 일정이 삭제되고, 전체 삭제는 두 사람의 모든 공유 일정을 삭제합니다. 실행 전 확인창을 표시하며 휴대폰 원본 일정은 유지합니다. [정책 및 설계](../backend/docs/calendar-removal.md).

### 일정 자동 갱신

캘린더 일정 화면을 보고 있을 때 15초마다 현재 월 일정과 캘린더 정보를 갱신합니다. 앱 복귀 시 즉시 조회하며, 백그라운드에서는 타이머를 중지합니다. 다른 화면/다이얼로그가 위에 있으면 주기 조회를 건너뛰고, 화면이 제거되면 타이머를 해제합니다. 이미 진행 중인 요청은 완료될 수 있으며 새 주기 요청은 중복 실행하지 않습니다.

조회 중/일시 실패 시 해당 월의 마지막 성공 데이터를 유지합니다. 오류 안내의 '갱신 다시 시도'로 수동 재시도할 수 있습니다. 이전에 불러온 적 없는 월은 로딩/오류 화면을 표시합니다. 403/404는 캘린더 삭제 또는 접근 권한 상실로 처리하여 안내 후 목록으로 이동합니다. 자동 갱신은 일정 화면에 적용되며, 캘린더 목록 자체의 주기 갱신과 푸시 알림은 포함하지 않습니다.

구현: `events_page.dart`에서 화면 수명에 맞춰 타이머와 월별 표시 캐시를 관리하고 `events_provider.dart`에서 별도 자동 재시도를 끄므로 백그라운드 재시도가 지속되지 않습니다. 서버 API와 DB 변경은 없습니다.

검증: `test/event_polling_test.dart`에서 15초 조회, 오류 시 데이터 유지, 백그라운드 중지, 복귀 즉시 조회, 화면 제거 후 중지, 403/404 목록 이동을 검사합니다.

일정 화면에서는 맨 아래에서 위로 충분히 당긴 뒤 놓아도 즉시 새로고침할 수 있습니다. 상단에서 아래로 당기는 일반적인 새로고침도 지원합니다. 일정이 적어 화면이 짧아도 동작하며, 요청 중 진행 표시와 중복 실행 방지를 제공합니다. 자동 갱신과 동일한 조회 함수를 사용합니다.
