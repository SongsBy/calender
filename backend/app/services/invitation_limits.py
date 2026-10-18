"""Persistent fixed-window limits shared by every API worker.

A separate transaction counts failed attempts as well as successful ones.
Only hashed scope keys are stored; caller-supplied forwarding headers are ignored.
"""

import hashlib
import math
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import case
from sqlalchemy.dialects.postgresql import insert
from sqlmodel import Session, col, delete

from app.core.db import engine
from app.models import InvitationRateLimit


def check_limits(limits: list[tuple[str, int, int]]) -> None:
    now = datetime.now(UTC)
    retry_after = 0
    with Session(engine) as session:
        # Bound retention of one-off IP keys without a background worker.
        session.exec(
            delete(InvitationRateLimit).where(
                col(InvitationRateLimit.expires_at) < now - timedelta(days=1)
            )
        )
        for scope, maximum, seconds in sorted(limits):
            key = hashlib.sha256(scope.encode()).hexdigest()
            expired = col(InvitationRateLimit.expires_at) <= now
            expires = now + timedelta(seconds=seconds)
            statement = insert(InvitationRateLimit).values(
                key_hash=key, attempts=1, expires_at=expires
            )
            count_statement = statement.on_conflict_do_update(
                index_elements=["key_hash"],
                set_={
                    "attempts": case(
                        (expired, 1), else_=col(InvitationRateLimit.attempts) + 1
                    ),
                    "expires_at": case(
                        (expired, expires), else_=col(InvitationRateLimit.expires_at)
                    ),
                },
            ).returning(
                col(InvitationRateLimit.attempts), col(InvitationRateLimit.expires_at)
            )
            attempts, deadline = session.execute(count_statement).one()
            if attempts > maximum:
                retry_after = max(
                    retry_after, math.ceil((deadline - now).total_seconds())
                )
        session.commit()
    if retry_after:
        raise HTTPException(
            status_code=429,
            detail={
                "code": "INVITATION_RATE_LIMIT",
                "message": "초대 요청이 너무 많습니다. 잠시 후 다시 시도해주세요.",
            },
            headers={"Retry-After": str(retry_after)},
        )
