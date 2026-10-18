# 아이디 가입과 Access/Refresh 인증 구현 보고

2026-10-13. 공유 캘린더의 2단계 인증을 구현했다. 캘린더·초대·일정·Android 일정 가져오기는 후속 단계다.

## 구현 구조

| 파일 | 역할 |
| --- | --- |
| `app/models.py` | 정규화된 username, 선택 이메일, 토큰 응답·검증 모델, RefreshSession 테이블 |
| `app/alembic/versions/a31f0b8c9d20_add_username_refresh_sessions.py` | 기존 User·Item 보존, 임시 username 백필, email nullable 변경, 세션 테이블 생성 |
| `app/crud.py` | username 또는 기존 이메일로 계정 조회·비밀번호 검증, 비밀번호 변경 시 세션 폐기 |
| `app/services/auth.py` | Refresh Token 해시 저장·교체·재사용 감지·세션 폐기 |
| `app/core/security.py` | 사용자·세션 ID·토큰 용도·만료를 포함한 Access JWT 발급 |
| `app/api/deps.py` | 서명·필수 claim·용도·만료·활성 계정·폐기된 세션 검사 |
| `app/api/routes/login.py`, `users.py` | 기존 URL을 유지하며 아이디 가입·로그인·갱신·로그아웃 제공 |
| `frontend/lib/core/api_client.dart` | 401 단일 갱신과 원래 요청 1회 재시도, 403 유지, 로그인/로그아웃 경합 방어 |
| `frontend/lib/core/storage.dart` | 모바일 OS 보안 저장소에 토큰 쌍 저장, 웹 메모리 세션, 기존 평문 토큰 정리 |
| `frontend/lib/providers/auth_provider.dart` | 로그인·서버 로그아웃·현재 사용자 상태 관리 |

기존 Item 파일·데이터·화면을 유지한다. Python 패키지 파일도 유지했다. 웹 빌드 폴더가 없는 로컬 환경에서도 API를 실행할 수 있도록 `main.py`에서 정적 화면 연결을 조건부로 변경했다.

## 실제 흐름

1. 가입: username을 trim/lowercase 처리하고 3~30자 영문 소문자·숫자·밑줄로 검증한다. 공개 가입에는 username이 필수이며 email은 생략할 수 있다. 중복은 DB UNIQUE 제약으로 막고 409를 반환한다. 공개 요청으로 관리자 권한을 설정할 수 없다.
2. 로그인: 비밀번호 해시를 검증하고 첫 RefreshSession 행을 만든다. 해당 행 ID가 세션 계열 ID(sid/family_id)다. 기본 Access 수명은 15분, 계열의 절대 수명은 30일이다.
3. 갱신: 사용자 행에 PostgreSQL 행 잠금을 걸고 토큰 행을 다시 읽는다. 사용 전 토큰만 새 토큰으로 교체하며 기존 토큰은 사용 완료 표시한다. 토큰 교체가 30일 절대 만료를 연장하지 않는다.
4. 재사용: 이미 사용한 Refresh Token이 다시 오면 계열 전체를 폐기하고 커밋한 뒤 401을 반환한다. 다른 로그인 계열은 유지된다.
5. 로그아웃: 현재 계열을 폐기한다. 일반 API도 계열의 폐기 상태를 검사하므로 남아 있는 Access Token도 사용할 수 없다. 비밀번호 변경·재설정은 사용자의 모든 계열을 폐기한다.
6. Flutter: 여러 API의 401은 하나의 갱신 Future를 기다린다. 실패한 요청은 새 Access Token으로 한 번만 재시도한다. 403은 갱신하거나 로그아웃하지 않는다. 로그아웃·새 로그인 중 이전 갱신 응답이 도착해도 과거 세션을 복구하지 않는다.

Refresh 원문은 반환할 때만 사용하고 DB에는 SHA-256 해시만 저장한다. 비밀번호는 기존 Argon2를 유지한다. 로그인·갱신·비밀번호 변경이 같은 사용자 행 잠금 순서를 사용하므로 동시 갱신에 두 승자가 생기지 않는다. 엄격한 재사용 차단 정책상 응답 유실 시 재로그인이 필요할 수 있다.

## API 사용

기본 경로 `/api/v1`.

| API | 요청 | 응답 |
| --- | --- | --- |
| POST `/users/signup` | JSON username,password,full_name?,email? | 201 UserPublic |
| POST `/login/access-token` | form username,password | 200 access_token,refresh_token,expires_in,token_type |
| POST `/login/refresh` | JSON refresh_token | 200 새 토큰 쌍 |
| POST `/login/logout` | Bearer Access Token, 본문 없음 | 204 |
| GET `/users/me` | Bearer Access Token | 200 본인 정보 |

예시 가입 본문:

```json
{"username":"user_one","password":"example-password-123","full_name":"사용자1"}
```

기존 이메일 로그인은 전환 호환용으로 허용한다. 기존 계정과 관리자/개발용 생성 경로에서 username을 생략하면 `legacy_` 접두사의 임시 아이디를 부여한다. 공개 가입에서 이 접두사는 사용할 수 없다. 아이디 변경 화면은 이번 범위에 포함하지 않았다. `/users/me`와 프로필 화면에서 현재 아이디를 확인할 수 있다.

이메일 없는 계정은 자동 비밀번호 복구를 사용할 수 없다. 가입 메일에서 비밀번호 전달을 제거했다. 복구 토큰에는 별도 용도를 부여하여 Access Token으로 사용할 수 없게 했다.

## 실행과 DB 적용

초기 검증은 별도 PostgreSQL 컨테이너와 `_test` DB에서 수행했다. 이후 로컬 앱의 500 오류를 확인하면서 개발 DB(`localhost:5432/app`)에도 `a31f0b8c9d20`을 적용했다. 원인은 이전 스키마에 `user.username` 컬럼과 `refresh_sessions` 테이블이 없었던 것이다. 적용 전 로컬 백업을 만들고, 기존 사용자 1건과 Item 2건의 모든 기존 필드가 유지됨을 확인했다.

실행 중인 서버에서 로그인 200, 내 정보 200, 갱신 200, 로그아웃 204, 폐기 세션 접근 401을 확인했다. 다른 개발 환경에서 처음 적용할 때는 `.env`의 DB 대상을 확인하고 다음을 실행한다.

```bash
cd backend
uv run alembic upgrade head
uv run python -m app.initial_data
uv run fastapi dev
```

기존 로그인 토큰에는 세션 ID가 없으므로 업데이트 후 다시 로그인해야 한다. 새 마이그레이션은 계정 ID·이메일·비밀번호 해시·Item 소유 관계를 유지한다. 이메일 없는 계정이 있으면 downgrade를 거절하며, 이메일을 임의 생성하거나 계정을 삭제하지 않는다.

테스트는 별도 빈 PostgreSQL DB를 생성하고 환경변수 `DATABASE_URL`로 지정한다. DB 이름은 반드시 `_test`로 끝나야 한다. 해당 URL을 지정한 셸에서 `uv run alembic upgrade head` 후 `uv run pytest tests -q`를 실행한다. 기존 fixture가 데이터를 정리하므로 `_test` 검사로 개발 DB에서의 오실행을 차단했다.

Flutter 실행은 `frontend`에서 `flutter run -d chrome --dart-define=API_URL=http://localhost:8000` 또는 Android 에뮬레이터에 `--dart-define=API_URL=http://10.0.2.2:8000`을 사용한다. 웹은 실행 포트를 서버 CORS의 FRONTEND_HOST와 맞춰야 한다. `flutter run -d chrome --web-port=5173`을 사용하면 기존 기본값과 일치한다.

## 검증 결과

- 기존 회귀 포함 백엔드 pytest: 67개 통과.
- Flutter 화면·API·보안 저장소 테스트: 21개 통과.
- Flutter 서비스 → 실제 FastAPI → 격리 PostgreSQL 통합 테스트: 6개 통과.
- 신규 마이그레이션: 기존 사용자와 Item 데이터 보존, 이메일 없는 계정의 downgrade 차단, 안전한 downgrade 및 재적용 확인.
- Python Ruff·mypy 및 Flutter analyze 통과.
- Flutter 웹 빌드 및 Android debug APK 빌드 성공.
- Chrome에서 로그인·회원가입의 아이디 입력 및 선택 이메일 표시 확인.

보안 저장소 복원 테스트는 플러그인 모의 구현을 사용했다. Android 실기기에서 재시작 후 복원, iOS 실제 서명·Keychain 동작은 아직 확인하지 않았다. Android 백업은 암호화 키와 토큰 데이터가 불일치하지 않도록 비활성화했고, iOS Keychain entitlement를 추가했다.

웹은 토큰을 메모리에만 보관하므로 페이지를 새로고침하면 다시 로그인한다. 서버 로그아웃 요청이 네트워크 문제로 실패하면 기기 토큰을 제거하고 서버 폐기를 확인하지 못했다는 안내를 표시한다. 운영 전 인증 시도 제한, 이메일 소유 확인, 운영 웹 쿠키 정책, 만료 세션 정리 작업은 추가로 구현해야 한다.
