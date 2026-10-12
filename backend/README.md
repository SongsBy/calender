# Backend

FastAPI + SQLModel + PostgreSQL

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

커버리지 리포트는 `htmlcov/index.html`에 생성됩니다.

## 마이그레이션

모델을 수정한 뒤:

```bash
uv run alembic revision --autogenerate -m "설명"
uv run alembic upgrade head
```

## 이메일 템플릿

`app/email-templates/*.html`을 직접 수정합니다. 템플릿 변수는 `app/utils.py`의 `generate_*_email()`에서 넘겨줍니다.
