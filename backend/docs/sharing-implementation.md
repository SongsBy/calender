# 공유 캘린더 연결 구현

2026-10-13. 인증 다음 단계인 캘린더 생성·초대·참여를 구현했다. 일정 CRUD, 달력 날짜 표시, Android 일정 가져오기는 다음 단계다.

## 사용 순서

1. Flutter를 재시작하고 로그인 → 메뉴의 **공유 캘린더** 또는 Dashboard의 **공유 캘린더 열기**.
2. 계정 A: **새 캘린더** → 이름 입력 → **상대방 초대하기** → **초대코드 발급** → 코드 복사.
3. 같은 API 서버를 사용하는 다른 앱/Chrome에서 계정 B로 로그인 → **초대코드로 참여** → 코드 입력.
4. A 화면에서 **새로고침**하면 두 화면에 같은 캘린더와 두 참여자가 표시된다. 앱이 다시 활성화될 때도 다시 조회한다. 실시간 구독은 아직 없다.

Android 에뮬레이터는 PC의 서버 주소로 `http://10.0.2.2:8000`, PC Chrome은 `http://localhost:8000`을 사용한다. 같은 PostgreSQL에 연결된 동일 API 서버여야 한다. Chrome 주소는 서버의 FRONTEND_HOST CORS 설정과 일치해야 한다. 실기기는 PC LAN 주소와 같은 네트워크를 사용하며 서버의 외부 인터페이스 바인딩이 필요하다.

## 파일과 처리 흐름

- `app/api/routes/calendars.py`, `invitations.py`: 인증 의존성, 요청 검증, 응답, 요청 횟수 제한 호출.
- `app/services/calendars.py`: 구성원 권한, 생성 트랜잭션, 초대 발급·수락, 계정 삭제 제한.
- `app/services/invitation_limits.py`: PostgreSQL에 요청 횟수를 저장. 워커/서버 재시작에도 동일한 제한 적용.
- `app/models.py`: 테이블과 입력·공개 응답 모델.
- `frontend/lib/services/calendars_service.dart`: Dio API 호출 및 목록 페이지 전체 조회.
- `frontend/lib/providers/calendars_provider.dart`: 로그인 사용자별 조회 상태. 생성·참여·새로고침 후 재조회.
- `frontend/lib/features/calendars/`: 목록, 빈 상태, 실패/재시도, 생성·참여 입력, 초대코드 발급·복사.

요청은 Flutter → Bearer 인증 → API → 서비스 → PostgreSQL 순서로 처리한다. 기존 로그인, Items API/데이터와 템플릿 파일을 유지했다.

## DB와 안전 조건

`b42c1d9e0f31` revision은 다음 네 테이블을 추가한다.

| 테이블 | 역할 |
| --- | --- |
| calendars | 이름, 시간대, 생성자 |
| calendar_members | 캘린더와 사용자 연결, 역할과 슬롯 |
| calendar_invitations | 코드 해시, 만료·사용·취소 시각 |
| invitation_rate_limits | 해시된 제한 범위, 요청 횟수와 만료 시각 |

- 슬롯 1은 owner, 슬롯 2는 member. 슬롯 CHECK와 캘린더별 슬롯 UNIQUE로 세 번째 참여를 DB에서도 막는다.
- 캘린더 목록과 상세 조회는 구성원만 가능하다. 관리자도 임의로 조회할 수 없다. 참여자 응답에는 이름·역할만 필요한 범위로 포함하고 이메일·아이디·권한 플래그를 노출하지 않는다.
- 초대는 생성자만 발급한다. 12자리 난수, 기본 24시간, 한 번 사용. DB에는 SHA-256 해시만 저장하며 발급 응답에서만 원문을 전달한다. 하이픈·공백·소문자 입력을 정규화한다.
- 재발급은 이전 미사용 코드를 취소한다. 자기 수락·기존 참여·만료·재사용·정원 초과를 거절한다.
- 발급과 수락 모두 캘린더 행을 먼저 잠근다. 구성원 추가와 코드 사용 처리는 한 트랜잭션이라 동시 수락도 한 명만 성공한다.
- 발급은 계정당 시간당 5회, 수락은 계정당 10분 10회/IP당 10분 30회. 실패 요청도 별도 트랜잭션에서 계산하고 429와 Retry-After를 반환한다. 배포 시 신뢰할 프록시와 실제 클라이언트 IP 전달 설정을 확인해야 한다.
- 탈퇴·캘린더 삭제는 아직 미구현이므로 참여 중인 계정 삭제는 409로 제한한다.

## API

Swagger: http://localhost:8000/docs (`calendars`, `invitations` 태그).

| 메서드 | 경로 (/api/v1 기준) | 기능 |
| --- | --- | --- |
| POST | /calendars | 생성 (name, timezone) |
| GET | /calendars | 내 목록 (skip, limit) |
| GET | /calendars/{id} | 구성원만 상세 조회 |
| POST | /calendars/{id}/invitations | 생성자 초대 발급 |
| POST | /invitations/accept | code로 참여 |

## 검증과 로컬 반영

- 격리 PostgreSQL에서 백엔드 전체 78개 통과. 만료, 자기 수락, 재발급, 재사용, 동시 수락, 재발급과 수락 경쟁, 요청 제한, DB 슬롯 제약, 비구성원/관리자 접근 거절 포함.
- Alembic check: 모델과 DB 차이 없음. Ruff·mypy 통과.
- Flutter 일반 테스트 24개 통과. 생성 입력 검증, 목록 갱신, 명시적 코드 발급·복사, 수락 실패 후 재시도, 360px 화면 overflow 검사 포함.
- Flutter CalendarsService를 실제 격리 API에 연결한 E2E 1개 통과: A 생성 → B 참여 → 양쪽 조회 → C의 조회/참여 거절.
- 로컬 개발 DB를 백업 후 revision 적용. 기존 user/item/refresh_sessions 행이 동일한지 비교했다. 실행 중인 localhost:8000에서 로그인·캘린더 목록 200 확인.
- Flutter analyze, 웹 빌드, Android debug APK 빌드 통과. 브라우저 연결이 없어 실제 브라우저 조작 검증은 완료하지 못했다.
- 실제 두 휴대폰, 배포 환경, Android 기기 캘린더 읽기는 아직 검증하지 않았다.

E2E는 계정/캘린더 데이터를 남기므로 반드시 폐기 가능한 테스트 DB에서 실행한다.

```sh
cd frontend
flutter test test/e2e/calendar_sharing_test.dart --dart-define=RUN_CALENDAR_E2E=true --dart-define=API_URL=http://127.0.0.1:58000
```

다음 구현: 캘린더별 일정 등록·기간 조회·작성자만 수정/삭제 → Flutter 달력의 날짜 표시와 일정 목록.
