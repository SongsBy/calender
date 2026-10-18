# 안드로이드 일정 가져오기

## 사용 흐름

공유 캘린더의 **기기 일정 가져오기** → 읽기 권한 허용 → 기기 캘린더와 기간 선택 → 일정 조회 → 공유할 일정 선택 → 공유하기.

- Android 전용. READ_CALENDAR만 요청하며 원본을 수정하지 않습니다.
- 기기에 저장/동기화된 일정만 조회합니다. 원격 Google Calendar API를 호출하지 않습니다.
- 최대 93일 조회, 최대 100개 선택. 조회 결과가 1,000개를 넘으면 기간 축소 안내.
- 제목, 시간, 설명을 선택 화면에서 확인하고 최종 확인 후 전송합니다.
- 반복 일정은 CalendarContract.Instances로 회차별 복사. 예외 회차의 원본 ID/원본 발생 시간을 사용합니다.
- 종일 일정은 UTC 날짜 그대로 보존하고 종료 날짜는 제외합니다.
- 권한 거부 시 설정 이동 제공. 재허용 후 '캘린더 다시 읽기' 또는 시작 버튼으로 재시도합니다.

## 서버 구조

`POST /api/v1/calendars/{calendar_id}/events/import`

요청: `installation_id` UUID와 `events` 배열(1~100). 각 원소는 기존 EventCreate 필드와 `source_calendar_id`, `source_event_id`, `occurrence_key`를 포함합니다.

응답: `created_count`, `skipped_count`, 새로 생성한 일정 `data`.

인증 사용자에서 작성자를 결정하고 캘린더 멤버십을 검사합니다. 전체 입력 검증 후 하나의 트랜잭션으로 저장합니다. 캘린더 행 잠금으로 동시 가져오기를 직렬화하고, `event_import_sources`의 unique 제약으로 중복을 방어합니다.

중복 키: 사용자 + 설치 ID + 대상 캘린더 + 원본 캘린더/일정 ID + 발생 회차. 중복은 건너뛰고 기존 공유 일정은 덮어쓰지 않습니다. 이벤트 삭제 시 출처 기록도 삭제되어 재가져오기가 가능합니다.

설치 ID는 Android noBackupFilesDir에 저장되어 계정 전환/앱 업데이트에는 유지되고 삭제/재설치에는 새로 생성됩니다. 재설치 또는 원본 ID 변경 후 중복 방지는 보장하지 않습니다.

## 적용 및 검증

백엔드 디렉터리에서 `../.venv/bin/alembic upgrade head`로 `d64e3f102b53` 적용. 네이티브 코드 추가이므로 Flutter hot restart만으로는 부족하며 APK 재빌드/설치가 필요합니다.

테스트: API 비회원/미인증 거부, A 가져오기/B 열람, 타인 삭제 거부, 동일 요청/동시 요청 중복 방지, 잘못된 배치 전체 미저장, 삭제 후 재가져오기. Flutter는 권한 거부, 조회 실패, 선택/최종 확인, 종일 날짜 및 조회 경계를 검증합니다.

실기기 확인: 기본 캘린더 앱에 시간 일정·종일 일정·반복 일정 생성 → A가 선택 가져오기 → B 새로고침 → 재가져오기 시 건너뜀 → 원본 수정 후 공유 복사본이 유지되는지 확인.

## 범위

이번 기능은 선택한 일정의 복사입니다. 원본 변경/삭제 자동 동기화, iOS 가져오기, 실시간 푸시는 포함하지 않습니다.

참고: https://developer.android.com/reference/android/provider/CalendarContract.Instances
