"""Atomic imports serialized per calendar; source copies are never overwritten."""

import uuid

from sqlmodel import Session, select

from app.models import (
    Event,
    EventCreate,
    EventImportRequest,
    EventImportResult,
    EventImportSource,
    EventPublic,
)
from app.services.events import accessible_calendar


def import_events(
    session: Session,
    calendar_id: uuid.UUID,
    user_id: uuid.UUID,
    body: EventImportRequest,
) -> EventImportResult:
    accessible_calendar(session, calendar_id, user_id)
    # accessible_calendar holds the calendar lock through commit.
    created = []
    for item in body.events:
        source = {
            "imported_by": user_id,
            "installation_id": body.installation_id,
            "calendar_id": calendar_id,
            "source_calendar_id": item.source_calendar_id,
            "source_event_id": item.source_event_id,
            "occurrence_key": item.occurrence_key,
        }
        existing = session.exec(select(EventImportSource).filter_by(**source)).first()
        if existing is not None:
            continue
        values = item.model_dump(include=set(EventCreate.model_fields))
        event = Event.model_validate(
            values, update={"calendar_id": calendar_id, "created_by": user_id}
        )
        session.add(event)
        session.flush()
        session.add(EventImportSource.model_validate({"event_id": event.id, **source}))
        session.flush()
        created.append(EventPublic.model_validate(event))
    session.commit()
    return EventImportResult(
        created_count=len(created),
        skipped_count=len(body.events) - len(created),
        data=created,
    )
