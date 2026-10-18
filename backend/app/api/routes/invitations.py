from fastapi import APIRouter, Request

from app.api.deps import CurrentUser, SessionDep
from app.models import CalendarPublic, InvitationAccept
from app.services.calendars import accept_invitation
from app.services.invitation_limits import check_limits

router = APIRouter(prefix="/invitations", tags=["invitations"])


@router.post("/accept")
def accept(
    body: InvitationAccept,
    request: Request,
    session: SessionDep,
    current_user: CurrentUser,
) -> CalendarPublic:
    peer = request.client.host if request.client else "unknown"
    check_limits(
        [(f"accept:user:{current_user.id}", 10, 600), (f"accept:ip:{peer}", 30, 600)]
    )
    return accept_invitation(session, current_user.id, body.code)
