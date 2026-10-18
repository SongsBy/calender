import uuid
from typing import Annotated

from fastapi import APIRouter, Query, Response

from app.api.deps import CurrentUser, SessionDep
from app.models import CalendarCreate, CalendarPublic, CalendarsPublic, InvitationPublic
from app.services import calendars
from app.services.invitation_limits import check_limits

router = APIRouter(prefix="/calendars", tags=["calendars"])


@router.post("", status_code=201)
def create_calendar(
    session: SessionDep, current_user: CurrentUser, body: CalendarCreate
) -> CalendarPublic:
    return calendars.create_calendar(session, current_user, body)


@router.get("")
def list_calendars(
    session: SessionDep,
    current_user: CurrentUser,
    skip: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=200)] = 100,
) -> CalendarsPublic:
    return calendars.list_calendars(session, current_user.id, skip, limit)


@router.get("/{calendar_id}")
def read_calendar(
    calendar_id: uuid.UUID, session: SessionDep, current_user: CurrentUser
) -> CalendarPublic:
    calendar = calendars.get_calendar(session, calendar_id, lock=True)
    calendars.require_member(session, calendar_id, current_user.id)
    return calendars.calendar_public(session, calendar)


@router.post("/{calendar_id}/invitations", status_code=201)
def issue_invitation(
    calendar_id: uuid.UUID, session: SessionDep, current_user: CurrentUser
) -> InvitationPublic:
    check_limits([(f"issue:user:{current_user.id}", 5, 3600)])
    return calendars.issue_invitation(session, calendar_id, current_user.id)


@router.post("/{calendar_id}/leave", status_code=204)
def leave_calendar(
    calendar_id: uuid.UUID, session: SessionDep, current_user: CurrentUser
) -> Response:
    calendars.leave_calendar(session, calendar_id, current_user.id)
    return Response(status_code=204)


@router.delete("/{calendar_id}", status_code=204)
def delete_calendar(
    calendar_id: uuid.UUID, session: SessionDep, current_user: CurrentUser
) -> Response:
    calendars.delete_calendar(session, calendar_id, current_user.id)
    return Response(status_code=204)
