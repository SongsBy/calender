from collections.abc import Generator
from datetime import UTC, datetime
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jwt.exceptions import InvalidTokenError
from pydantic import ValidationError
from sqlmodel import Session

from app.core import security
from app.core.config import settings
from app.core.db import engine
from app.models import RefreshSession, TokenPayload, User
from app.services.auth import unauthorized

reusable_oauth2 = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_STR}/login/access-token"
)


def get_db() -> Generator[Session]:
    with Session(engine) as session:
        yield session


SessionDep = Annotated[Session, Depends(get_db)]
TokenDep = Annotated[str, Depends(reusable_oauth2)]


def get_token_payload(token: TokenDep) -> TokenPayload:
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[security.ALGORITHM],
            options={"require": ["exp", "iat", "sub", "sid", "token_type"]},
        )
        return TokenPayload.model_validate(payload)
    except InvalidTokenError, ValidationError:
        raise unauthorized()


TokenPayloadDep = Annotated[TokenPayload, Depends(get_token_payload)]


def get_current_user(session: SessionDep, token_data: TokenPayloadDep) -> User:
    user = session.get(User, token_data.sub)
    root = session.get(RefreshSession, token_data.sid)
    if (
        not user
        or not user.is_active
        or not root
        or root.user_id != user.id
        or root.family_id != root.id
        or root.revoked_at is not None
        or root.expires_at <= datetime.now(UTC)
    ):
        raise unauthorized()
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def get_current_active_superuser(current_user: CurrentUser) -> User:
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=403, detail="The user doesn't have enough privileges"
        )
    return current_user
