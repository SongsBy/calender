"""Login sessions. All mutations serialize on the owning User row."""

import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException
from sqlmodel import Session, col, select, update

from app.core.config import settings
from app.core.security import create_access_token
from app.models import RefreshSession, Token, User


def unauthorized() -> HTTPException:
    return HTTPException(
        status_code=401,
        detail="Invalid or expired credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def lock_user(session: Session, user_id: uuid.UUID) -> User:
    user = session.exec(
        select(User)
        .where(User.id == user_id)
        .with_for_update()
        .execution_options(populate_existing=True)
    ).first()
    if user is None:
        raise unauthorized()
    return user


def revoke_user_sessions(session: Session, user_id: uuid.UUID) -> None:
    session.exec(
        update(RefreshSession)
        .where(col(RefreshSession.user_id) == user_id)
        .values(revoked_at=datetime.now(UTC))
    )


def revoke_family(session: Session, user_id: uuid.UUID, family_id: uuid.UUID) -> None:
    lock_user(session, user_id)
    session.exec(
        update(RefreshSession)
        .where(
            col(RefreshSession.user_id) == user_id,
            col(RefreshSession.family_id) == family_id,
        )
        .values(revoked_at=datetime.now(UTC))
    )
    session.commit()


def issue_tokens(
    session: Session, user: User, previous: RefreshSession | None = None
) -> Token:
    # Caller holds the User lock; root row is the stable family/session identifier.
    now = datetime.now(UTC)
    raw = secrets.token_urlsafe(48)
    row_id = uuid.uuid4()
    row = RefreshSession(
        id=row_id,
        user_id=user.id,
        family_id=previous.family_id if previous else row_id,
        token_hash=token_hash(raw),
        expires_at=previous.expires_at
        if previous
        else now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )
    if previous:
        previous.used_at = now
        previous.replaced_by_id = row_id
        session.add(previous)
    session.add(row)
    access = create_access_token(
        user.id,
        timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        session_id=row.family_id,
    )
    session.commit()
    return Token(
        access_token=access,
        refresh_token=raw,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


def rotate_tokens(session: Session, raw: str) -> Token:
    row = session.exec(
        select(RefreshSession).where(RefreshSession.token_hash == token_hash(raw))
    ).first()
    if row is None:
        raise unauthorized()
    user = lock_user(session, row.user_id)
    session.refresh(
        row
    )  # Re-read after waiting for a concurrent refresh/password change.
    now = datetime.now(UTC)
    if row.used_at is not None:
        revoke_family(session, user.id, row.family_id)  # Commit before raising.
        raise unauthorized()
    if not user.is_active or row.revoked_at is not None or row.expires_at <= now:
        raise unauthorized()
    return issue_tokens(session, user, row)
