"""Calendar-scoped events; membership for reads, authorship for mutations."""

import uuid
from datetime import UTC, date, datetime, time
from zoneinfo import ZoneInfo

from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError
from sqlalchemy import DateTime, case, cast
from sqlmodel import Session, and_, col, func, or_, select

from app.models import (
    Calendar,
    Event,
    EventCreate,
    EventPublic,
    EventsPublic,
    EventUpdate,
)
from app.services.calendars import get_calendar, problem, require_member


def accessible_calendar(
    session: Session, calendar_id: uuid.UUID, user_id: uuid.UUID
) -> Calendar:
    calendar = get_calendar(session, calendar_id, lock=True)
    require_member(session, calendar_id, user_id)
    return calendar


def get_event(
    session: Session, calendar_id: uuid.UUID, event_id: uuid.UUID, *, lock: bool = False
) -> Event:
    query = select(Event).where(Event.id == event_id, Event.calendar_id == calendar_id)
    if lock:
        query = query.with_for_update().execution_options(populate_existing=True)
    event = session.exec(query).first()
    if event is None:
        raise problem(404, "EVENT_NOT_FOUND", "일정을 찾을 수 없습니다.")
    return event


def require_author(event: Event, user_id: uuid.UUID) -> None:
    if event.created_by != user_id:
        raise problem(
            403,
            "EVENT_AUTHOR_REQUIRED",
            "작성자만 일정을 수정하거나 삭제할 수 있습니다.",
        )


def create_event(
    session: Session, calendar_id: uuid.UUID, user_id: uuid.UUID, body: EventCreate
) -> EventPublic:
    accessible_calendar(session, calendar_id, user_id)
    event = Event.model_validate(
        body, update={"calendar_id": calendar_id, "created_by": user_id}
    )
    session.add(event)
    session.commit()
    session.refresh(event)
    return EventPublic.model_validate(event)


def read_event(
    session: Session, calendar_id: uuid.UUID, user_id: uuid.UUID, event_id: uuid.UUID
) -> EventPublic:
    accessible_calendar(session, calendar_id, user_id)
    return EventPublic.model_validate(get_event(session, calendar_id, event_id))


def list_events(
    session: Session,
    calendar_id: uuid.UUID,
    user_id: uuid.UUID,
    date_from: date,
    date_to: date,
    skip: int,
    limit: int,
) -> EventsPublic:
    calendar = accessible_calendar(session, calendar_id, user_id)
    if not 0 < (date_to - date_from).days <= 93:
        raise problem(
            422,
            "INVALID_EVENT_RANGE",
            "조회 기간은 1~93일이어야 합니다. 종료 날짜는 제외합니다.",
        )
    zone = ZoneInfo(calendar.timezone)
    try:
        start = datetime.combine(date_from, time.min, zone).astimezone(UTC)
        end = datetime.combine(date_to, time.min, zone).astimezone(UTC)
    except OverflowError:
        raise problem(422, "INVALID_EVENT_RANGE", "시간대로 변환할 수 없는 날짜입니다.")
    filters = and_(
        Event.calendar_id == calendar_id,
        or_(
            and_(
                col(Event.all_day).is_(False),
                col(Event.starts_at) < end,
                col(Event.ends_at) > start,
            ),
            and_(
                col(Event.all_day).is_(True),
                col(Event.start_date) < date_to,
                col(Event.end_date) > date_from,
            ),
        ),
    )
    count = session.exec(select(func.count()).select_from(Event).where(filters)).one()
    # All-day starts sort as midnight in this calendar's timezone, not the DB timezone.
    start_order = case(
        (
            col(Event.all_day).is_(True),
            func.timezone(calendar.timezone, cast(col(Event.start_date), DateTime())),
        ),
        else_=col(Event.starts_at),
    )
    rows = session.exec(
        select(Event)
        .where(filters)
        .order_by(start_order, col(Event.id))
        .offset(skip)
        .limit(limit)
    ).all()
    return EventsPublic(
        data=[EventPublic.model_validate(row) for row in rows], count=count
    )


def update_event(
    session: Session,
    calendar_id: uuid.UUID,
    user_id: uuid.UUID,
    event_id: uuid.UUID,
    body: EventUpdate,
) -> EventPublic:
    accessible_calendar(session, calendar_id, user_id)
    event = get_event(session, calendar_id, event_id, lock=True)
    require_author(event, user_id)
    changes = body.model_dump(exclude_unset=True)
    if not changes:
        return EventPublic.model_validate(event)
    # When switching kind, clear old fields, but validate any explicitly supplied fields.
    if body.all_day is not None and body.all_day != event.all_day:
        opposite = (
            ("starts_at", "ends_at") if body.all_day else ("start_date", "end_date")
        )
        for field in opposite:
            changes.setdefault(field, None)
    try:
        merged = EventCreate.model_validate(
            {**event.model_dump(include=set(EventCreate.model_fields)), **changes}
        )
    except ValidationError as error:
        errors = error.errors(include_context=False)
        for entry in errors:
            entry["loc"] = ("body", *entry["loc"])
        raise RequestValidationError(errors)
    event.sqlmodel_update(merged.model_dump())
    session.add(event)
    session.commit()
    session.refresh(event)
    return EventPublic.model_validate(event)


def delete_event(
    session: Session, calendar_id: uuid.UUID, user_id: uuid.UUID, event_id: uuid.UUID
) -> None:
    accessible_calendar(session, calendar_id, user_id)
    event = get_event(session, calendar_id, event_id, lock=True)
    require_author(event, user_id)
    session.delete(event)
    session.commit()
