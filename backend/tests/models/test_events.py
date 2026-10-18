import uuid
from datetime import UTC, date, datetime, timedelta

import pytest
from pydantic import ValidationError
from sqlalchemy.exc import DataError, IntegrityError, StatementError
from sqlmodel import Session

from app.core.db import engine
from app.models import Calendar, Event, User

START = datetime(2026, 10, 18, 19, tzinfo=UTC)


@pytest.fixture
def context():
    # Keep all rows isolated and roll them back after each test.
    with Session(engine) as session:
        user = User(username=f"event_{uuid.uuid4().hex[:20]}", hashed_password="unused")
        session.add(user)
        session.flush()
        calendar = Calendar(name="일정 테스트", created_by=user.id)
        session.add(calendar)
        session.flush()
        yield session, {"calendar_id": calendar.id, "created_by": user.id}
        session.rollback()


def timed(**changes):
    return {
        "title": "저녁 약속",
        "starts_at": START,
        "ends_at": START + timedelta(hours=1),
        **changes,
    }


def test_utc_storage_update_timestamp_and_all_day(context):
    session, refs = context
    local = datetime.fromisoformat("2026-10-18T19:00:00+09:00")
    event = Event.model_validate(
        timed(starts_at=local, ends_at=local + timedelta(hours=1)), update=refs
    )
    session.add(event)
    session.flush()
    session.refresh(event)
    assert event.starts_at == datetime(2026, 10, 18, 10, tzinfo=UTC)
    assert event.starts_at.utcoffset() == timedelta(0)
    old_created, old_updated = event.created_at, event.updated_at
    event.title = "변경된 약속"
    session.add(event)
    session.flush()
    session.refresh(event)
    assert event.created_at == old_created
    assert event.updated_at > old_updated
    holiday = Event.model_validate(
        {
            "title": "휴가",
            "all_day": True,
            "start_date": "2026-10-18",
            "end_date": "2026-10-19",
        },
        update=refs,
    )
    session.add(holiday)
    session.flush()
    session.refresh(holiday)
    assert holiday.start_date == date(2026, 10, 18)
    assert holiday.starts_at is None


@pytest.mark.parametrize(
    "changes",
    [
        {"ends_at": START},
        {"ends_at": START - timedelta(hours=1)},
        {"starts_at": None},
        {"ends_at": None},
        {"start_date": date(2026, 10, 18)},
        {"all_day": True},
        {"all_day": True, "starts_at": None, "ends_at": None},
        {
            "all_day": True,
            "starts_at": None,
            "ends_at": None,
            "start_date": date(2026, 10, 18),
            "end_date": date(2026, 10, 18),
        },
        {"title": "   "},
        {"title": "x" * 201},
        {"description": "x" * 5001},
    ],
)
def test_invalid_values_rejected_by_validation_and_database(context, changes):
    session, refs = context
    with pytest.raises(ValidationError):
        Event.model_validate(timed(**changes), update=refs)
    # Direct table construction skips Pydantic: DB must still protect integrity.
    with pytest.raises((IntegrityError, DataError)):
        with session.begin_nested():
            session.add(Event(**refs, **timed(**changes)))
            session.flush()


def test_naive_timestamp_rejected(context):
    session, refs = context
    values = timed(starts_at=datetime(2026, 10, 18, 10))
    with pytest.raises(ValidationError):
        Event.model_validate(values, update=refs)
    with pytest.raises(StatementError):
        with session.begin_nested():
            session.add(Event(**refs, **values))
            session.flush()


@pytest.mark.parametrize("key", ["calendar_id", "created_by"])
def test_missing_reference_rejected(context, key):
    session, refs = context
    with pytest.raises(IntegrityError):
        with session.begin_nested():
            session.add(Event(**{**refs, key: uuid.uuid4()}, **timed()))
            session.flush()


def test_author_delete_restricted_and_calendar_delete_cascades(context):
    session, refs = context
    event = Event(**refs, **timed())
    session.add(event)
    session.flush()
    with pytest.raises(IntegrityError):
        with session.begin_nested():
            session.delete(session.get(User, refs["created_by"]))
            session.flush()
    session.delete(session.get(Calendar, refs["calendar_id"]))
    session.flush()
    session.expunge_all()
    assert session.get(Event, event.id) is None
