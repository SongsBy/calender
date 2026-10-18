"""Calendar membership and one-use invitations, serialized per calendar."""

import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, col, delete, func, select, update

from app.core.config import settings
from app.models import (
    Calendar,
    CalendarCreate,
    CalendarInvitation,
    CalendarMember,
    CalendarMemberPublic,
    CalendarPublic,
    CalendarsPublic,
    Event,
    InvitationPublic,
    User,
)

CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def problem(status: int, code: str, message: str) -> HTTPException:
    return HTTPException(status_code=status, detail={"code": code, "message": message})


def hash_code(code: str) -> str:
    return hashlib.sha256(code.encode()).hexdigest()


def normalize_code(code: str) -> str:
    return "".join(code.upper().split()).replace("-", "")


def get_calendar(
    session: Session, calendar_id: uuid.UUID, *, lock: bool = False
) -> Calendar:
    query = select(Calendar).where(Calendar.id == calendar_id)
    if lock:
        query = query.with_for_update().execution_options(populate_existing=True)
    calendar = session.exec(query).first()
    if calendar is None:
        raise problem(404, "CALENDAR_NOT_FOUND", "캘린더를 찾을 수 없습니다.")
    return calendar


def require_member(
    session: Session, calendar_id: uuid.UUID, user_id: uuid.UUID
) -> CalendarMember:
    member = session.get(CalendarMember, (calendar_id, user_id))
    if member is None:
        raise problem(403, "NOT_CALENDAR_MEMBER", "이 캘린더에 참여할 권한이 없습니다.")
    return member


def calendar_public(session: Session, calendar: Calendar) -> CalendarPublic:
    rows = session.exec(
        select(CalendarMember, User)
        .join(User, col(User.id) == col(CalendarMember.user_id))
        .where(CalendarMember.calendar_id == calendar.id)
        .order_by(col(CalendarMember.slot))
    ).all()
    members = [
        CalendarMemberPublic(
            id=user.id,
            full_name=user.full_name,
            username=user.username,
            role="owner" if member.role == "owner" else "member",
            slot=member.slot,
        )
        for member, user in rows
    ]
    return CalendarPublic(
        id=calendar.id,
        name=calendar.name,
        timezone=calendar.timezone,
        created_at=calendar.created_at,
        members=members,
    )


def create_calendar(
    session: Session, user: User, body: CalendarCreate
) -> CalendarPublic:
    calendar = Calendar.model_validate(body, update={"created_by": user.id})
    session.add(calendar)
    session.flush()
    session.add(
        CalendarMember(calendar_id=calendar.id, user_id=user.id, role="owner", slot=1)
    )
    session.commit()
    session.refresh(calendar)
    return calendar_public(session, calendar)


def list_calendars(
    session: Session, user_id: uuid.UUID, skip: int, limit: int
) -> CalendarsPublic:
    filters = CalendarMember.user_id == user_id
    count = session.exec(
        select(func.count()).select_from(CalendarMember).where(filters)
    ).one()
    calendars = session.exec(
        select(Calendar)
        .join(CalendarMember, col(Calendar.id) == col(CalendarMember.calendar_id))
        .where(filters)
        .order_by(col(Calendar.created_at).desc(), col(Calendar.id))
        .offset(skip)
        .limit(limit)
    ).all()
    return CalendarsPublic(
        data=[calendar_public(session, c) for c in calendars], count=count
    )


def issue_invitation(
    session: Session, calendar_id: uuid.UUID, user_id: uuid.UUID
) -> InvitationPublic:
    get_calendar(session, calendar_id, lock=True)
    member = require_member(session, calendar_id, user_id)
    if member.role != "owner":
        raise problem(403, "OWNER_REQUIRED", "캘린더를 만든 사람만 초대할 수 있습니다.")
    count = session.exec(
        select(func.count())
        .select_from(CalendarMember)
        .where(CalendarMember.calendar_id == calendar_id)
    ).one()
    if count >= 2:
        raise problem(409, "CALENDAR_FULL", "이미 두 명이 참여한 캘린더입니다.")
    now = datetime.now(UTC)
    session.exec(
        update(CalendarInvitation)
        .where(
            col(CalendarInvitation.calendar_id) == calendar_id,
            col(CalendarInvitation.used_at).is_(None),
            col(CalendarInvitation.revoked_at).is_(None),
        )
        .values(revoked_at=now)
    )
    # Hash collisions are extraordinarily unlikely, but handle them without
    # rolling back revocation of the previous active invitation.
    for _ in range(5):
        code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(12))
        invitation = CalendarInvitation(
            calendar_id=calendar_id,
            created_by=user_id,
            code_hash=hash_code(code),
            expires_at=now + timedelta(hours=settings.INVITATION_EXPIRE_HOURS),
        )
        try:
            with session.begin_nested():
                session.add(invitation)
                session.flush()
            break
        except IntegrityError:
            continue
    else:
        session.rollback()
        raise problem(
            503,
            "INVITATION_UNAVAILABLE",
            "초대코드를 만들지 못했습니다. 다시 시도해주세요.",
        )
    session.commit()
    return InvitationPublic(
        id=invitation.id, code=code, expires_at=invitation.expires_at
    )


def accept_invitation(
    session: Session, user_id: uuid.UUID, raw_code: str
) -> CalendarPublic:
    code = normalize_code(raw_code)
    invalid = problem(
        400, "INVALID_INVITATION", "초대코드가 올바르지 않거나 만료되었습니다."
    )
    if len(code) != 12 or any(c not in CODE_ALPHABET for c in code):
        raise invalid
    invitation = session.exec(
        select(CalendarInvitation).where(
            CalendarInvitation.code_hash == hash_code(code)
        )
    ).first()
    if invitation is None:
        raise invalid
    # Always lock calendar first (same order as issuing/reissuing invitations).
    calendar = get_calendar(session, invitation.calendar_id, lock=True)
    session.refresh(invitation, with_for_update=True)
    now = datetime.now(UTC)
    if invitation.revoked_at is not None or invitation.expires_at <= now:
        raise invalid
    if invitation.used_at is not None:
        raise problem(409, "INVITATION_USED", "이미 사용된 초대코드입니다.")
    if session.get(CalendarMember, (calendar.id, user_id)) is not None:
        raise problem(409, "ALREADY_MEMBER", "이미 참여 중인 캘린더입니다.")
    if session.exec(
        select(CalendarMember).where(
            CalendarMember.calendar_id == calendar.id, CalendarMember.slot == 2
        )
    ).first():
        raise problem(409, "CALENDAR_FULL", "이미 두 명이 참여한 캘린더입니다.")
    session.add(
        CalendarMember(calendar_id=calendar.id, user_id=user_id, role="member", slot=2)
    )
    invitation.used_at = now
    invitation.accepted_by = user_id
    session.add(invitation)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise problem(
            409, "CALENDAR_FULL", "캘린더 참여 상태가 변경되었습니다. 새로고침해주세요."
        )
    return calendar_public(session, calendar)


def ensure_user_can_be_deleted(session: Session, user_id: uuid.UUID) -> None:
    if session.exec(
        select(CalendarMember).where(CalendarMember.user_id == user_id)
    ).first():
        raise problem(
            409,
            "CALENDAR_MEMBERSHIP_EXISTS",
            "공유 캘린더에 참여 중인 계정은 아직 삭제할 수 없습니다.",
        )


def commit_user_deletion(session: Session) -> None:
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise problem(
            409,
            "SHARED_DATA_EXISTS",
            "공유 캘린더에서 사용 중인 계정은 삭제할 수 없습니다.",
        )


def leave_calendar(
    session: Session, calendar_id: uuid.UUID, user_id: uuid.UUID
) -> None:
    get_calendar(session, calendar_id, lock=True)
    member = require_member(session, calendar_id, user_id)
    if member.role == "owner":
        raise problem(
            409, "OWNER_CANNOT_LEAVE", "만든 사람은 나가기 대신 캘린더를 삭제해주세요."
        )
    # Remove private copies before opening the second membership slot again.
    session.exec(
        delete(Event).where(
            col(Event.calendar_id) == calendar_id, col(Event.created_by) == user_id
        )
    )
    session.exec(
        update(CalendarInvitation)
        .where(
            col(CalendarInvitation.calendar_id) == calendar_id,
            col(CalendarInvitation.revoked_at).is_(None),
        )
        .values(revoked_at=datetime.now(UTC))
    )
    session.delete(member)
    session.commit()


def delete_calendar(
    session: Session, calendar_id: uuid.UUID, user_id: uuid.UUID
) -> None:
    calendar = get_calendar(session, calendar_id, lock=True)
    member = require_member(session, calendar_id, user_id)
    if member.role != "owner":
        raise problem(403, "OWNER_REQUIRED", "만든 사람만 캘린더를 삭제할 수 있습니다.")
    # Existing database CASCADEs remove members, invitations, events and import records.
    session.delete(calendar)
    session.commit()
