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
scripts/   초기화·테스트 스크립트
compose*.yml  Docker Compose 설정
```

## 템플릿으로 새 프로젝트 시작하기

```bash
git clone git@github.com:SongsBy/my.git my-app
cd my-app
rm -rf .git && git init
python3 scripts/init_project.py --name "My App" --org com.example
```

`init_project.py`는 `.env`의 프로젝트 이름과 비밀 값을 새로 만들고, Flutter 앱 이름과 번들 ID(Android / iOS / macOS / web)를 바꿔 줍니다.
GitHub에서 저장소 설정의 **Template repository**를 켜 두면 **Use this template** 버튼으로도 만들 수 있습니다.

## 시작하기

### 1. 환경 변수

루트의 `.env`에서 `FIRST_SUPERUSER`, `FIRST_SUPERUSER_PASSWORD`를 수정합니다. `SECRET_KEY`와 `POSTGRES_PASSWORD`는 `init_project.py`가 생성하지만 직접 바꿔도 됩니다.

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
