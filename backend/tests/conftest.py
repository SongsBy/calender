from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, delete

from app.core.config import settings
from app.core.db import engine, init_db
from app.main import app
from app.models import (
    Calendar,
    CalendarInvitation,
    CalendarMember,
    Event,
    InvitationRateLimit,
    Item,
    User,
)
from tests.utils.user import authentication_token_from_email
from tests.utils.utils import get_superuser_token_headers


@pytest.fixture(scope="session", autouse=True)
def db() -> Generator[Session]:
    if not (engine.url.database or "").endswith("_test"):
        raise RuntimeError("Tests require a dedicated DATABASE_URL ending in _test")
    with Session(engine) as session:
        init_db(session)
        yield session
        session.exec(delete(Event))
        session.exec(delete(CalendarInvitation))
        session.exec(delete(CalendarMember))
        session.exec(delete(Calendar))
        session.exec(delete(InvitationRateLimit))
        statement = delete(Item)
        session.execute(statement)
        statement = delete(User)
        session.execute(statement)
        session.commit()


@pytest.fixture(scope="module")
def client() -> Generator[TestClient]:
    with TestClient(app) as c:
        yield c


@pytest.fixture
def superuser_token_headers(client: TestClient) -> dict[str, str]:
    return get_superuser_token_headers(client)


@pytest.fixture
def normal_user_token_headers(client: TestClient, db: Session) -> dict[str, str]:
    return authentication_token_from_email(
        client=client, email=settings.EMAIL_TEST_USER, db=db
    )
