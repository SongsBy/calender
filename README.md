# FastAPI + Flutter Full Stack

FastAPI 백엔드와 Flutter 프론트엔드로 구성된 풀스택 프로젝트입니다.

## 스택

- **Backend**: FastAPI, SQLModel, PostgreSQL, Alembic, JWT 인증
- **Frontend**: Flutter (Web / iOS / Android / macOS), go_router, Riverpod, dio
- **Infra**: Docker Compose, Traefik, Mailpit, GitHub Actions

## 구조

```
backend/   FastAPI 앱, 마이그레이션, 테스트
frontend/  Flutter 앱
compose*.yml  Docker Compose 설정
```

## 시작하기

### 1. 환경 변수

루트의 `.env`에서 `SECRET_KEY`, `FIRST_SUPERUSER`, `FIRST_SUPERUSER_PASSWORD`, `POSTGRES_PASSWORD`를 수정합니다.

### 2. 백엔드

```bash
docker compose up -d db mailpit
cd backend
uv sync
uv run bash scripts/prestart.sh
uv run fastapi dev
```

API: http://localhost:8000 · 문서: http://localhost:8000/docs

### 3. 프론트엔드

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define=API_URL=http://localhost:8000
```

### Docker로 한 번에 실행

```bash
docker compose run --rm backend bash scripts/prestart.sh
docker compose up -d
```

Flutter 웹 빌드가 백엔드 이미지에 포함되어 http://localhost:8000 에서 함께 서빙됩니다.

## 테스트

```bash
cd backend && uv run bash scripts/test.sh
cd frontend && flutter test
```

## 배포

- FastAPI Cloud: [deployment.md](./deployment.md)
- Docker Compose 자체 호스팅: [deployment-docker-compose.md](./deployment-docker-compose.md)

## 라이선스

MIT. 원본은 [fastapi/full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template)입니다.
