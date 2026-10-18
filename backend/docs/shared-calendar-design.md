# 두 사람 공유 캘린더: 1단계 설계

작성일: 2026-10-13

상태: 인증 단계 구현 완료. username 확장, refresh_sessions, 로그인·갱신·로그아웃과 Flutter 연동을 구현했다. 캘린더·초대·일정 API는 아직 설계 상태다.
인증 마이그레이션과 서버는 격리된 테스트 DB에서 검증했고, 이후 로컬 개발 DB에도 데이터 보존을 확인하며 적용했다. 외부 배포는 수행하지 않았다. 상세 결과는 [인증 구현 보고](auth-implementation.md)를 참고한다.

## 1. 기존 FastAPI 파일 검토

결정: 기존 기반을 유지하고 기능별로 확장한다. 기존 파일과 데이터를 지우고 다시 시작하지 않는다.

| 대상 | 확인한 역할 | 개발 방침 |
| --- | --- | --- |
| `app/__init__.py`, `app/api/__init__.py`, 각 패키지의 `__init__.py` | Python 패키지 파일 | 유지. 비어 있어도 삭제 대상으로 보지 않는다. |
| `app/main.py` | FastAPI 생성, CORS, API 등록, Flutter 웹 정적 파일 연결 | 유지. 로컬 웹 주소 등 실행 설정만 필요한 단계에 조정한다. |
| `app/api/main.py` | 기능별 라우터 등록 | 유지. calendars, invitations, events 라우터를 추가한다. |
| `app/core/config.py`, `db.py` | 환경 설정, SQLModel 엔진·관리자 초기화 | 유지. 토큰 수명·초대 설정과 username 초기화를 확장한다. |
| `app/core/security.py` | Argon2 기반 비밀번호 처리, JWT 발급 | 재사용. 토큰 종류·세션 식별 및 Refresh Token 처리를 추가한다. |
| `app/api/deps.py` | DB 세션, 로그인 사용자, 관리자 검사 | 확장. 인증 오류 401, 캘린더 구성원 검사, 세션 폐기 검사를 추가한다. |
| `app/models.py` | User·Item 테이블 및 입출력 모델 | 기존 테이블 유지. 우선 같은 파일에 관련 모델을 추가해 import·메타데이터 등록을 단순하게 유지한다. |
| `app/crud.py` | 사용자·Item DB 처리 | 기존 호출부 유지. username 조회를 추가한다. 여러 작업을 한 번에 커밋하는 로직은 서비스에 둔다. |
| `app/api/routes/users.py` | 가입, 내 정보, 관리자 계정 관리, 계정 삭제 | 확장. username 가입과 공유 데이터가 있는 계정의 삭제 제한을 반영한다. |
| `app/api/routes/login.py` | 이메일 로그인, Access Token, 비밀번호 복구 | 기존 URL을 재사용하며 username 로그인·갱신·로그아웃으로 확장한다. 복구 로직도 계정 정책에 맞춰 수정한다. |
| `app/api/routes/items.py`, Item 모델·테스트 | 개인 소유 데이터 예제, 현재 Flutter에서 사용 | 당장 유지. 캘린더로 이름만 바꾸지 않는다. Flutter 전환과 회귀 확인 후 별도 작업으로 제거 여부를 결정한다. |
| `app/api/routes/private.py` | development에서만 등록되는 인증 없는 테스트 사용자 생성 | 개발·테스트용으로 유지. 공개 회원가입에는 사용하지 않고 운영 환경에서는 등록되지 않음을 검증한다. |
| `app/api/routes/utils.py`, `app/utils.py`, 이메일 템플릿 | 상태 확인·메일·복구 지원 | 유지. 가입 메일에 비밀번호를 전달하는 현재 흐름은 인증 변경 시 제거한다. |
| `app/alembic/`, `app/initial_data.py`, 기존 테스트 | DB 변경 이력, 초기 사용자, 회귀 검증 | 유지. 이전 마이그레이션 수정·삭제 대신 새 revision을 추가한다. |

검토 당시 `items.py`, Item 테스트, Flutter Item 관련 파일 등에 미커밋 변경이 있었다. 해당 변경을 덮어쓰거나 되돌리지 않는다.

기능별 파일 배치는 다음과 같다. services/auth.py는 구현했으며 calendars·events는 후속 단계에서 생성한다.

```text
app/
  models.py                      기존 모델 + 신규 테이블·입출력 모델
  crud.py                        기존 사용자·Item 처리
  services/
    auth.py                      토큰 갱신·세션 폐기 트랜잭션
    calendars.py                 캘린더 생성·초대 발급·수락
    events.py                    일정 처리·가져오기
  api/routes/
    users.py, login.py           기존 경로 확장
    calendars.py                 캘린더·구성원 조회
    invitations.py               초대 발급·수락
    events.py                    일정 CRUD·가져오기
```

라우터는 요청·응답을, 서비스는 권한과 업무 규칙·트랜잭션을 담당한다. 서비스 안에서 사용하는 DB 함수는 임의로 commit하지 않고 서비스가 한 번에 commit한다. 기존 CRUD의 commit 방식은 기존 호출부와 함께 필요한 범위에서만 조정한다.

## 2. 기능 규칙과 초기 선택

- 각자 username과 비밀번호로 가입한다. username은 앞뒤 공백 제거 후 소문자로 정규화하고 `[a-z0-9_]{3,30}`으로 제한한다. 표시 이름은 별도로 둔다.
- 비밀번호는 기존의 8~128자 범위를 유지하고 해시로 저장한다. 공백 제거·소문자 변환을 적용하지 않는다.
- 초기 결정: 이메일은 선택 항목으로 둔다. 이메일 없이도 가입·로그인 가능하다. 이메일 없는 계정의 자동 비밀번호 복구는 MVP에서 제공하지 않는다.
- 공개 가입 입력에는 `is_superuser`, `is_active`를 받지 않는다.
- 사용자1이 캘린더를 생성하면 첫 구성원(owner)이 된다. 사용자2가 초대를 수락하면 같은 캘린더의 두 번째 구성원(member)이 된다.
- 캘린더당 최대 2명이다. DB는 한 사용자가 여러 캘린더에 참여할 수 있게 한다. MVP 화면은 선택한 캘린더 하나를 보여준다.
- 두 사람 모두 일정을 등록·열람하고, 수정·삭제는 작성자만 한다. owner나 superuser라는 이유로 상대방 일정을 수정하거나 공유 권한을 우회하지 않는다.
- 초대 발급·재발급은 owner만 한다. 코드는 24시간 유효한 일회용 12자리 난수 코드로 시작한다. 혼동 문자를 제외한 문자 집합을 사용하고 입력 시 대문자·공백/구분자 정규화를 적용한다.
- 코드는 복사·휴대폰 공유 기능으로 전달한다. 메일 발송이나 앱 내부 메시지는 MVP에 포함하지 않는다.
- 구성원 탈퇴·교체·캘린더 삭제는 후속 기능이다. 그 전까지 구성원이거나 공유 데이터에 참조된 계정의 기존 삭제 API는 409로 거절한다. 본인 삭제와 관리자 삭제에 동일하게 적용한다.
- 화면 진입·앱 복귀·새로고침 시 재조회한다. 실시간 푸시, 원본 일정 자동 동기화, 반복 일정 직접 생성은 후속 범위다.

## 3. DB 관계와 제약조건

기존 물리 테이블 이름은 `user`, `item`이다. 이전 계획의 `users`는 개념상 이름이었으며 실제 `user` 테이블을 유지한다. 신규 테이블은 명시적으로 아래 이름을 사용한다. 기본키는 UUID, 기록 시각은 UTC를 사용한다.

관계: user → calendar_members ← calendars → events. 초대는 calendars에, 로그인 세션은 user에 연결된다. 가져오기 기록은 events에 연결된다.

| 테이블 | 필드 및 관계 | 제약·인덱스 |
| --- | --- | --- |
| `user` 확장 | 기존 필드, `username`; `email`은 nullable로 변경 | 정규화된 username UNIQUE NOT NULL; email의 기존 UNIQUE 유지 |
| `refresh_sessions` | id, user_id, family_id, token_hash, created_at, expires_at, used_at, revoked_at, replaced_by_id | token_hash UNIQUE; user_id·family_id 인덱스; 교체한 토큰도 계열 만료까지 남겨 재사용 감지 |
| `calendars` | id, name, created_by, timezone, created_at | name 1~100자; timezone은 IANA 이름 검증, 초기값 Asia/Seoul |
| `calendar_members` | calendar_id, user_id, role, slot, joined_at | PK(calendar_id,user_id); UNIQUE(calendar_id,slot); slot은 1 또는 2; role은 owner/member; owner는 slot 1, member는 slot 2 |
| `calendar_invitations` | id, calendar_id, created_by, code_hash, expires_at, used_at, accepted_by, revoked_at, created_at | code_hash UNIQUE; calendar_id 인덱스; 원문 코드는 응답 시 한 번만 노출 |
| `events` | id, calendar_id, created_by, title, description, all_day, starts_at, ends_at, start_date, end_date, created_at, updated_at | calendar_id·시간/날짜 범위 인덱스; title 1~200자, description 최대 5000자; 아래 시간 제약 |
| `event_import_sources` | id, event_id, calendar_id, imported_by, installation_id, source_calendar_id, source_event_id, occurrence_key, imported_at | event_id UNIQUE; UNIQUE(imported_by,installation_id,calendar_id,source_calendar_id,source_event_id,occurrence_key) |

모든 참조에 외래키를 둔다. 계정과 공유 데이터 간 참조는 삭제 제한(RESTRICT)을 기본으로 한다. 가져오기 기록은 event 삭제 시 CASCADE로 정리한다. 따라서 일정을 삭제한 뒤 같은 원본을 다시 가져오면 새 일정으로 등록할 수 있다.

시간 제약은 API 검증과 DB CHECK로 함께 적용한다.

- `all_day=false`: starts_at/ends_at 필수, 날짜 필드는 NULL, ends_at > starts_at. 입력에 UTC 오프셋을 요구한다.
- `all_day=true`: start_date/end_date 필수, 시각 필드는 NULL, end_date > start_date.
- 모든 종료값은 제외 구간이다. 10월 13일 하루 종일 일정은 start_date=2026-10-13, end_date=2026-10-14이다.
- PATCH는 기존 값과 합친 최종 상태를 검증한다. 종일 여부 전환 시 반대쪽 날짜/시각 필드를 비운다.

### 초대 수락과 동시 요청

하나의 트랜잭션 안에서 캘린더 행을 잠근 뒤 초대 행을 잠근다. 발급·재발급도 같은 잠금 순서를 사용한다. 만료·사용·폐기·현재 인원을 검사하고 두 번째 구성원 추가와 코드 사용 처리를 함께 커밋한다. slot UNIQUE 제약은 동시에 서로 다른 초대코드가 수락되어도 세 번째 구성원이 생기는 것을 막는다.

재발급은 같은 캘린더의 기존 미사용 코드를 폐기한다. 자기 초대 수락과 이미 참여한 사용자의 수락은 409로 거절한다. 코드는 해시로만 저장하고 로그에 남기지 않는다. 발급과 수락에는 사용자·IP별 시도 제한을 적용한다. 초기값은 발급 사용자당 5회/시간, 수락 사용자당 10회/10분·IP당 30회/10분이며 초과 시 429와 Retry-After를 반환한다. 로컬 단일 프로세스 제한과 운영 다중 프로세스 공용 제한 저장소를 구분해 검증한다.

## 4. 인증 계약

- 기존 `/api/v1/users/signup`, `/api/v1/login/access-token`을 확장한다. 병렬로 `/auth/login`을 만들지 않는다.
- Access Token은 15분, Refresh 계열은 최초 로그인부터 최대 30일이다. 갱신이 계열의 절대 만료를 연장하지 않는다.
- 로그인 응답은 access_token, refresh_token, token_type=bearer, expires_in=900이다.
- JWT에는 sub(사용자), sid(세션 계열), token_type=access, iat, exp를 넣고 필요한 claim·서명·만료·사용자 상태·계열 폐기 여부를 검사한다. 비밀번호 복구 토큰과 용도를 구분한다.
- Refresh Token은 충분히 긴 암호학적 난수 문자열로 만들고 SHA-256 해시만 DB에 보관한다. 비밀번호는 기존 Argon2를 유지한다.
- 갱신은 계열 잠금 후 기존 토큰을 사용 완료 처리하고 새 행을 생성하는 원자적 작업이다. 사용된 토큰 재사용은 해당 계열 전체 폐기 후 401이다. 실패 응답을 보내더라도 폐기 커밋이 롤백되지 않게 한다.
- 일반 API도 활성 계열을 확인하므로 로그아웃한 계열의 Access Token을 즉시 거절한다. 비밀번호 변경·재설정 시 모든 계열을 폐기한다.
- Flutter는 동시에 한 번만 갱신하고 대기 중 요청을 이어서 보낸다. 엄격한 일회용 갱신 정책이므로 갱신 응답 유실 후 이전 토큰을 무작정 재전송하지 않고 재로그인을 안내한다.
- 모바일 Refresh Token은 OS 보안 저장소에 보관한다. 로컬 웹 검증에서는 메모리에 보관하고 페이지 재시작 시 다시 로그인한다. 운영 웹 장기 로그인은 HttpOnly 쿠키·CSRF 정책을 별도 설계한다.
- 잘못된 인증·만료·폐기·비활성 계정은 401, 로그인했지만 권한 없음은 403, 없는 리소스는 404, 중복·정원 초과·현재 상태 충돌은 409, 입력 오류는 422다.

## 5. API 명세

기본 경로는 `/api/v1`. 회원가입·로그인·갱신 외 아래 업무 API는 Bearer 인증을 요구한다. 기존 상태 확인·개발 전용 API의 인증 정책은 기존 용도를 따른다. 단건은 객체, 목록은 `{data: [...], count: 전체개수}`를 사용한다. 목록은 skip=0, limit=100(최대 200), 일정 정렬은 시작값·id 순으로 고정한다.

| Method / 경로 | 요청 | 성공 응답 | 권한·주요 오류 |
| --- | --- | --- | --- |
| POST `/users/signup` | JSON username,password,full_name,email? | 201: UserPublic | 공개; 아이디·이메일 중복 409 |
| POST `/login/access-token` | form username,password | 200: TokenPair | 공개; 실패 401 |
| POST `/login/refresh` | JSON refresh_token | 200: TokenPair | Refresh 검증; 실패 401 |
| POST `/login/logout` | 본문 없음 | 204 | 현재 계열 폐기; 이미 폐기된 인증은 401, 앱은 로컬 토큰 정리 |
| GET `/users/me` | 없음 | 200: UserPublic | 본인 |
| POST `/calendars` | JSON name,timezone? | 201: CalendarPublic | 로그인 사용자; owner 참여까지 원자적 생성 |
| GET `/calendars` | skip,limit | 200: CalendarList | 자신이 참여한 것만 |
| GET `/calendars/{id}` | 없음 | 200: CalendarPublic | 구성원; 403/404 |
| POST `/calendars/{id}/invitations` | 없음 | 201: id,code,expires_at | owner; 403/409/429 |
| POST `/invitations/accept` | JSON code | 200: CalendarPublic | 잘못됨·만료·폐기 400, 사용됨·중복참여·정원초과 409, 제한 429 |
| GET `/calendars/{id}/events` | from,to,skip,limit | 200: EventList | 구성원; 403/404/422 |
| POST `/calendars/{id}/events` | JSON EventCreate | 201: EventPublic | 구성원; 작성자는 서버 결정 |
| GET `/calendars/{id}/events/{event_id}` | 없음 | 200: EventPublic | 구성원; 다른 캘린더의 event_id는 404 |
| PATCH `/calendars/{id}/events/{event_id}` | JSON EventUpdate | 200: EventPublic | 구성원이면서 작성자; 403/404/422 |
| DELETE `/calendars/{id}/events/{event_id}` | 없음 | 204 | 구성원이면서 작성자; 403/404 |
| POST `/calendars/{id}/events/import` | JSON installation_id,events | 200: ImportResult | 구성원; 최대 100건; 403/404/422 |

`/events/import`는 `/{event_id}`와 충돌하지 않도록 정적 경로를 먼저 등록한다. 멤버 목록은 CalendarPublic에 id,full_name,slot,role만 포함하고 상대방 이메일·관리자 여부·세션 정보는 노출하지 않는다.

### 입출력 예시

회원가입 요청:

```json
{"username":"user_one","password":"example-only-password","full_name":"사용자1"}
```

UserPublic은 id,username,email(nullable),full_name,is_active,is_superuser,created_at을 반환한다. 기존 관리자 화면 호환을 위해 기존 공개 필드를 유지하되 공유 상대방 응답에는 위의 축약 필드만 사용한다.

CalendarPublic 예시(실제 id는 UUID):

```json
{"id":"<uuid>","name":"우리 일정","timezone":"Asia/Seoul","created_at":"2026-10-13T00:00:00Z","members":[{"id":"<user-uuid>","full_name":"사용자1","slot":1,"role":"owner"}]}
```

시간 일정 등록:

```json
{"title":"저녁 약속","description":null,"all_day":false,"starts_at":"2026-10-13T19:00:00+09:00","ends_at":"2026-10-13T20:00:00+09:00"}
```

종일 일정 등록:

```json
{"title":"휴가","all_day":true,"start_date":"2026-10-13","end_date":"2026-10-14"}
```

EventPublic은 id,calendar_id,created_by,title,description,all_day,starts_at,ends_at,start_date,end_date,created_at,updated_at을 반환한다. 사용하지 않는 날짜/시각 필드는 null이다. EventUpdate는 같은 입력 필드를 선택적으로 받되 id,calendar_id,created_by와 원본 연결정보는 수정할 수 없다. 부분 수정의 동시 충돌은 MVP에서 마지막 저장 우선으로 처리한다.

기간 조회의 from/to는 `YYYY-MM-DD`, to는 제외, 최대 93일로 제한한다. 시간 일정은 캘린더 시간대의 두 날짜 자정을 UTC로 바꿔 `starts_at < to AND ends_at > from`으로 조회한다. 종일 일정도 같은 겹침 조건을 날짜에 적용한다. Flutter는 count만큼 페이지를 모두 읽고 날짜 표시를 계산하며, 일부 페이지를 전체 결과처럼 표시하지 않는다. 슬롯별 색상에 이름을 함께 표시한다.

업무 오류는 `{"detail":{"code":"CALENDAR_FULL","message":"이미 두 명이 참여한 캘린더입니다."}}` 형태로 통일한다. 422 입력 오류는 FastAPI 검증 형식을 유지한다. 기존 API의 문자열 detail도 Flutter 전환 중 처리한다.

## 6. Android 일정 가져오기

권한 요청 → 기기 캘린더·기간 조회 → 일정 선택 → 공유될 내용 확인 → 서버 업로드 순서다. 서버는 기기 저장소에 직접 접근하지 않는다. 기기 읽기 권한이 서버 업로드 동의까지 의미하지 않는다.

기간 안의 반복 발생 건을 개별 일정으로 복사한다. 각 건은 EventCreate 필드와 source_calendar_id,source_event_id,occurrence_key를 포함한다. occurrence_key는 시간 일정의 원본 발생 시작 UTC 시각 또는 종일 일정의 원본 발생 날짜다. 원본 수정 추적이나 반복 규칙 동기화는 하지 않는다.

```json
{"installation_id":"<install-uuid>","events":[{"source_calendar_id":"1","source_event_id":"42","occurrence_key":"2026-10-13T10:00:00Z","title":"저녁 약속","all_day":false,"starts_at":"2026-10-13T19:00:00+09:00","ends_at":"2026-10-13T20:00:00+09:00"}]}
```

ImportResult는 `{created_count, skipped_count, data: [EventPublic]}`이며 data는 이번에 생성된 일정만 포함한다. 요청 전체를 검증한 뒤 한 트랜잭션으로 저장한다. 중복 키는 건너뛰고 기존 공유 일정 내용을 덮어쓰지 않는다. 동시 중복 요청은 UNIQUE 제약과 savepoint/충돌 처리로 제어해 고아 일정이 생기지 않게 한다. 네트워크 재시도에도 동일 키가 유지되어야 한다.

설치 식별자는 로그인 계정과 별개로 생성·보관한다. 재설치·기기 교체·원본 ID 변경에 따른 중복까지 보장하지 않으며, 제목·시간만 같은 서로 다른 일정을 자동 병합하지 않는다. 원본에서 수정·삭제해도 공유 복사본은 그대로 유지된다.

## 7. 데이터 보존과 전환 순서

1. 기존 DB와 Alembic head를 확인하고 테스트 전용 DB를 분리한다. 현재 `tests/conftest.py`는 연결된 DB의 Item·User를 정리하므로 개발 데이터가 있는 DB에 그대로 실행하지 않는다.
2. 새 revision으로 user.username을 nullable로 추가한다. 기존 계정에는 예약 접두사 `legacy_`와 UUID hex 앞 23자(총 30자)를 조합한 임시 username을 부여한다. 충돌 시 난수 접미사를 다시 생성해 중복을 확인한다. 신규 가입에서는 legacy_ 접두사를 금지한다. 기존 계정의 실제 로그인 아이디 전환 방법을 안내하고 단계적으로 확정한다.
3. 백필·중복 확인 후 username UNIQUE NOT NULL을 적용한다. email nullable 변경과 UserCreate/UserPublic/메일 호출부를 함께 변경한다. 이메일 없는 가입에 가짜 이메일을 만들지 않는다.
4. 관리자 초기화·private 사용자 생성·테스트 fixture도 username을 제공하게 바꾼다. 기존 계정의 이메일 로그인은 이관 기간 동안만 지원하며 새 username 형식에는 @가 없어 식별 방식을 구분할 수 있다.
5. Refresh 세션 도입과 Flutter 저장·갱신 로직을 함께 반영한다. sid 없는 기존 토큰은 전환 시 만료 처리하고 재로그인한다.
6. 캘린더·멤버·초대 테이블을 추가한 뒤 일정·가져오기 테이블을 순서대로 추가한다. 외래키와 계정 삭제 제한도 같은 단계에서 적용한다.
7. Flutter를 캘린더 화면으로 전환한 뒤 Item의 참조·테스트·보존할 데이터를 검토한다. Item 제거는 별도 revision과 변경으로 수행하며 자동으로 데이터를 삭제하지 않는다.

Supabase 도입 시에도 FastAPI가 인증·권한을 담당하고 PostgreSQL 연결 대상만 변경한다. 앱은 DB 비밀번호나 관리 키를 보유하지 않는다. DB 전용 사용 시 앱 테이블의 외부 Data API 노출을 차단하고 전용 DB 역할의 권한을 제한하는 설정을 배포 단계에서 검증한다.

## 8. 단계별 구현과 검증 기준

| 단계 | 구현 산출물 | 검증 |
| --- | --- | --- |
| 1 설계 | 이 문서와 README 연결 | 기존 코드와의 차이, 요청·응답, 제약조건 검토 완료; 배포 연결 확인은 아직 미실행 |
| 2 인증 (구현 완료) | User 확장·마이그레이션, 로그인·갱신·로그아웃, Flutter 연동 | 가입·중복·401, 갱신 동시 요청·재사용·절대 만료, 로그아웃·비밀번호 변경 후 세션 차단 |
| 3 공유 (구현 완료) | 캘린더·초대 API와 화면 | A 생성→B 수락, 자기 초대·만료·재사용·세 번째 참여·동시 수락 거절 |
| 4 일정 (DB·CRUD API 완료) | Event 모델·마이그레이션, CRUD·기간 조회 API | 구성원 A/B 조회, 상대방 수정 거절, C의 목록·단건·수정·삭제·가져오기 차단, 경로의 캘린더와 일정 불일치 거절 |
| 5 달력 (구현 완료) | Flutter 날짜 표시·목록·등록·편집·삭제 | 사용자 색상·이름, 여러 날 일정, 종일·시간대·종료 제외 경계, 로딩·빈 상태·실패 상태 |
| 6 가져오기 | Android 읽기·선택·업로드 | 권한 거절, 반복 발생, 종일, 재가져오기·동시 재시도 중복 방지, 원본 변경 시 복사본 유지 |
| 7 배포 | HTTPS 서버·운영 DB·실기기 연결 | 서로 다른 네트워크의 두 계정 공유, 재시작 후 유지, 비구성원 차단, 운영 private 경로 미등록 |

로컬은 동일 서버·DB에 연결한 Android 에뮬레이터와 Chrome에서 A/B로 로그인해 검증한다. 사용자 C는 접근 거절 확인용이다. Android 가져오기는 Android 실행 환경에서 확인한다. 새로고침 기반 동작을 기준으로 검증하고 즉시 자동 반영을 완료 조건으로 오해하지 않는다.

서버의 기존 `/api/v1/utils/health-check/`는 프로세스 응답 확인용이며 DB 연결 성공까지 보장하지 않는다. 배포 연결 점검은 상태 확인과 별도의 DB 왕복 조회를 함께 수행한다. 실행·네트워크 검증 결과는 실제 수행 후 기록한다.

공유 연결 구현 상세 및 검증: [sharing-implementation.md](sharing-implementation.md).


## 9. 일정 DB 모델 구현 (2026-10-18)

`app/models.py`의 `EventBase`는 제목·기간 검증을, `Event`는 `events` 테이블 매핑을 담당한다. 기존 Item은 유지했다. 새 revision은 `c53d2e0f1a42`이며 API 라우트와 Flutter 일정 화면은 아직 추가하지 않았다.

- `id`, `calendar_id`, `created_by`: UUID. 캘린더 삭제 시 해당 일정은 CASCADE, 작성자 삭제는 RESTRICT. 캘린더 삭제 API 자체는 아직 없다.
- `title`: 앞뒤 공백 제거 후 1~200자. `description`: 선택, 최대 5000자.
- `all_day=false`: 오프셋이 있는 `starts_at`, `ends_at`을 UTC로 저장한다. 날짜 필드는 NULL.
- `all_day=true`: `start_date`, `end_date`로 저장한다. 시각 필드는 NULL.
- 종료는 시작보다 뒤여야 하며 종료값은 제외한다. 예: 10월 18일 하루 휴가는 `2026-10-18`부터 `2026-10-19`까지다.
- DB CHECK는 필수 기간의 NULL, 시간·날짜 혼용, 역전·동일 기간, 공백 제목을 차단한다. VARCHAR 길이와 외래키도 DB에서 검증한다.
- `(calendar_id, starts_at, ends_at)`, `(calendar_id, start_date, end_date)` 복합 인덱스와 작성자 인덱스를 추가했다.
- `created_at`, `updated_at`은 UTC다. SQLModel/SQLAlchemy UPDATE에서는 `updated_at`이 자동 갱신된다. 직접 SQL로 UPDATE할 때는 호출자가 함께 갱신해야 한다(DB 트리거는 없음).
- 입력은 `Event.model_validate(data, update={"calendar_id": ..., "created_by": ...})`로 검증한다. 테이블 생성자 `Event(...)`는 Pydantic 검증을 생략하므로 외부 입력에 그대로 사용하지 않는다.
- 작성자의 캘린더 참여 여부·요청자의 조회/수정 권한은 다음 API 단계에서 검사한다. 외래키는 사용자와 캘린더의 존재만 보장한다.
- 기존 데이터가 있는 `events`의 downgrade는 중단한다. 데이터 없는 테스트 DB에서만 즉시 이전 revision으로 되돌릴 수 있다.

검증: 일정 모델 테스트 16개를 포함한 백엔드 94개 통과, Ruff·mypy 통과. 격리 PostgreSQL에서 downgrade/upgrade 및 Alembic check 통과. 로컬 DB는 백업 후 적용했고 기존 7개 테이블의 행이 동일한지 비교했다.


## 10. 일정 API 구현 (2026-10-18)

`app/api/routes/events.py`가 요청·응답을 처리하고 `app/services/events.py`가 권한·조회·트랜잭션을 처리한다. `EventCreate`, `EventUpdate`, `EventPublic`, `EventsPublic`을 추가했다. DB 스키마는 이전 단계와 같아 새 마이그레이션은 필요 없다. 기존 Items API는 유지한다.

| 메서드 | /api/v1 기준 경로 | 결과 |
| --- | --- | --- |
| POST | /calendars/{calendar_id}/events | 201, 일정 등록 |
| GET | /calendars/{calendar_id}/events?from=2026-10-01&to=2026-11-01 | 200, 기간에 겹치는 일정과 전체 count |
| GET | /calendars/{calendar_id}/events/{event_id} | 200, 단건 |
| PATCH | /calendars/{calendar_id}/events/{event_id} | 200, 작성자 부분 수정 |
| DELETE | /calendars/{calendar_id}/events/{event_id} | 204, 작성자 삭제 |

Swagger의 `events` 태그에서 로그인 토큰으로 확인한다. 아래는 POST 요청 본문이다.

```json
{
  "title": "저녁 약속",
  "description": "함께 식사",
  "all_day": false,
  "starts_at": "2026-10-18T19:00:00+09:00",
  "ends_at": "2026-10-18T20:00:00+09:00"
}
```

- 모든 경로에서 캘린더 구성원을 검사한다. 두 구성원 모두 작성·조회할 수 있고 수정·삭제는 작성자만 가능하다. owner·관리자에게 우회 권한은 없다.
- calendar_id는 경로에서, created_by는 로그인 인증에서 정한다. 본문에 id/created_by/calendar_id 등 허용하지 않은 필드를 보내면 422다.
- 다른 캘린더의 event_id와 없는 일정은 404다. 외부 계정은 403, 미인증은 401이다.
- from/to는 필수 날짜이고 to는 제외다. 최대 93일, skip >= 0, limit 1~200이다. 캘린더 시간대의 자정을 UTC로 바꿔 시간 일정과 겹침을 비교한다. 종일 일정은 날짜로 비교한다.
- 종일 일정의 시작은 캘린더 시간대의 자정으로 환산해 시간 일정과 함께 시작순·UUID순으로 정렬한다. count는 페이지 크기와 별개인 전체 건수다.
- PATCH는 기존 값과 합쳐 기간을 검증한다. all_day를 바꿀 때 이전 유형의 필드를 자동으로 비우며, 새 유형의 시작·종료값이 필요하다. description:null은 설명 삭제다. title/all_day:null 또는 필수 기간 null은 422다.
- 수정·삭제 시 일정 행을 잠근다. 동시 부분 수정이 서로 다른 필드를 덮어쓰지 않도록 잠금 후 최신 값을 읽는다. 같은 필드의 동시 수정은 마지막 저장 우선이다.
- 이번 단계에는 Flutter 일정 화면과 Android 가져오기 API를 포함하지 않는다. 날짜 선택·등록 화면 연결이 다음 작업이다.

검증: PostgreSQL을 사용하는 백엔드 전체 120개 통과. 이후 추가한 동시 PATCH·시간대 변환 범위 검사까지 포함해 일정 API 28개가 모두 통과했다. Ruff·mypy도 통과했다. 로컬 서버의 OpenAPI에 5개 연산이 반영된 것을 확인했다.

Flutter 일정 UI 구현 및 검증: [frontend README](../../frontend/README.md#공유-일정-ui-2026-10-18).
