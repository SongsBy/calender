import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query, Response

from app.api.deps import CurrentUser, SessionDep
from app.models import (
    EventCreate,
    EventImportRequest,
    EventImportResult,
    EventPublic,
    EventsPublic,
    EventUpdate,
)
from app.services import events
from app.services.event_imports import import_events

router = APIRouter(prefix="/calendars/{calendar_id}/events", tags=["events"])


@router.post("", status_code=201)
def create_event(
    calendar_id: uuid.UUID,
    body: EventCreate,
    session: SessionDep,
    current_user: CurrentUser,
) -> EventPublic:
    return events.create_event(session, calendar_id, current_user.id, body)


@router.get("")
def list_events(
    calendar_id: uuid.UUID,
    session: SessionDep,
    current_user: CurrentUser,
    date_from: Annotated[date, Query(alias="from")],
    date_to: Annotated[date, Query(alias="to")],
    skip: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=200)] = 100,
) -> EventsPublic:
    return events.list_events(
        session, calendar_id, current_user.id, date_from, date_to, skip, limit
    )


@router.post("/import")
def import_device_events(
    calendar_id: uuid.UUID,
    body: EventImportRequest,
    session: SessionDep,
    current_user: CurrentUser,
) -> EventImportResult:
    return import_events(session, calendar_id, current_user.id, body)


@router.get("/{event_id}")
def read_event(
    calendar_id: uuid.UUID,
    event_id: uuid.UUID,
    session: SessionDep,
    current_user: CurrentUser,
) -> EventPublic:
    return events.read_event(session, calendar_id, current_user.id, event_id)


@router.patch("/{event_id}")
def update_event(
    calendar_id: uuid.UUID,
    event_id: uuid.UUID,
    body: EventUpdate,
    session: SessionDep,
    current_user: CurrentUser,
) -> EventPublic:
    return events.update_event(session, calendar_id, current_user.id, event_id, body)


@router.delete("/{event_id}", status_code=204)
def delete_event(
    calendar_id: uuid.UUID,
    event_id: uuid.UUID,
    session: SessionDep,
    current_user: CurrentUser,
) -> Response:
    events.delete_event(session, calendar_id, current_user.id, event_id)
    return Response(status_code=204)
