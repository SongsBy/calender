# Backend

FastAPI + SQLModel + PostgreSQL

## 공유 캘린더 개발 설계

[두 사람 공유 캘린더 설계](docs/shared-calendar-design.md)에 기존 파일 유지·변경 방침,
DB 관계와 제약조건, 인증·초대·일정 API, Android 가져오기 및 단계별 검증 기준을 정리했습니다.
신규 기능의 구현 상태는 문서 첫 부분과 단계별 표를 확인하세요.
[인증 구현 보고와 실행 방법](docs/auth-implementation.md)에는 실제 구현·검증 범위를 정리했습니다.

## 요구 사항

- Docker
- [uv](https://docs.astral.sh/uv/)

## 실행

```bash
docker compose up -d db mailpit      # 프로젝트 루트에서
cd backend
uv sync
uv run bash scripts/prestart.sh      # 마이그레이션 + 첫 superuser 생성
uv run fastapi dev
```

- API: http://localhost:8000
- 문서: http://localhost:8000/docs
- 메일 확인: http://localhost:8025

## 주요 파일

```
app/models.py        SQLModel 모델
app/api/routes/      API 엔드포인트
app/crud.py          DB 조회·변경
app/core/config.py   설정 (.env)
app/email-templates/ 이메일 HTML (Jinja2)
alembic/versions/    마이그레이션
tests/               pytest
```

## 테스트

```bash
uv run bash scripts/test.sh
```

테스트는 개발 DB와 분리된 `DATABASE_URL`을 사용해야 하며 DB 이름이 `_test`로 끝나야 합니다.
테스트 fixture는 데이터를 정리하므로 실제 개발 DB를 지정하지 마세요.
커버리지 리포트는 `htmlcov/index.html`에 생성됩니다.

## 마이그레이션

모델을 수정한 뒤:

```bash
uv run alembic revision --autogenerate -m "설명"
uv run alembic upgrade head
```

## 이메일 템플릿

`app/email-templates/*.html`을 직접 수정합니다. 템플릿 변수는 `app/utils.py`의 `generate_*_email()`에서 넘겨줍니다.

공유 캘린더 생성·초대·참여: [구현 설명과 로컬 확인 방법](docs/sharing-implementation.md).

### Render 무료 인스턴스 시작 명령

Docker Command에는 따옴표 없이 `bash scripts/render-start.sh`를 입력합니다.
이 스크립트는 마이그레이션과 초기 관리자 생성을 완료한 뒤 Render의 `PORT`
(미설정 시 10000)에서 워커 1개로 서버를 실행합니다. 준비 단계가 실패하면
서버를 시작하지 않습니다. Health Check Path는 `/api/v1/utils/health-check/`입니다.
